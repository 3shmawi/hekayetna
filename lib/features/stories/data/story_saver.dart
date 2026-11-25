import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:family_stories/core/network/app_failure.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/features/family/data/family_repository.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/recording/data/draft_store.dart';
import 'package:family_stories/features/recording/data/segment_joiner.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/data/story_repository.dart';

/// What the save form collected. Text is stored as typed (ends trimmed).
class StorySaveRequest {
  const StorySaveRequest({
    required this.title,
    required this.visibility,
    this.description = '',
    this.dateLabel = '',
    this.year,
    this.topic,
    this.narratorIds = const [],
    this.peopleIds = const [],
    this.recipientUserIds = const [],
    this.photoIds = const [],
    this.waveform,
  });

  final String title;
  final String description;
  final String dateLabel;
  final int? year;
  final String? topic;
  final StoryVisibility visibility;
  final List<String> narratorIds;
  final List<String> peopleIds;
  final List<String> recipientUserIds;
  final List<String> photoIds;

  /// 64 values, 0..100, or null (no waveform known).
  final List<int>? waveform;
}

enum SavePhase { preparing, uploading, creating }

/// Turns a finished take into a story: join the segments, upload the audio,
/// create the story with its people, photos and recipients. On any failure
/// the draft stays on the phone and an uploaded orphan is removed; the draft
/// is deleted only after the story exists (spec 04, AC-6).
class StorySaver {
  StorySaver({
    required this.stories,
    required this.family,
    required this.drafts,
    required this.userId,
    this.joinTake = _joinTake,
    String Function()? newId,
    this.attemptTimeout = const Duration(minutes: 4),
  }) : _fixedId = newId;

  final StoryRepository stories;
  final FamilyRepository family;
  final DraftStore drafts;
  final String? userId;
  final Future<String> Function(StoryDraft draft) joinTake;
  final String Function()? _fixedId;

  /// How long one save waits before it reports "still uploading". The write
  /// itself is not cancelled by this: a later save of the same draft joins
  /// the attempt that is still running instead of starting a second one.
  final Duration attemptTimeout;

  final _inFlight = <String, _Attempt>{};

  /// Saves the take. One attempt per draft runs at a time: a second call
  /// (a double tap) joins the running attempt. After [attemptTimeout] this
  /// returns [TimeoutFailure] and the attempt keeps running (a timeout does
  /// not cancel a write). The next call first asks the backend whether the
  /// story already exists (the attempt may have landed remotely while its
  /// future never resolves) and returns it if so. If not, and the old attempt
  /// is still hung, a new attempt starts: every step is idempotent for the
  /// same owner and audio (id from owner + draft + audio digest, existing
  /// story reused, an existing object reused only if its size matches), so
  /// the two cannot create two stories.
  Future<Result<Story>> save(
    StoryDraft draft,
    StorySaveRequest request, {
    void Function(SavePhase phase)? onPhase,
  }) async {
    var attempt = _inFlight[draft.id];
    var replaced = false;
    if (attempt != null && attempt.timedOut) {
      final id = attempt.storyId;
      if (id != null) {
        final remote = await stories.getStory(id);
        if (remote case Success<Story?>(:final value?)) {
          _inFlight.remove(draft.id);
          await drafts.delete(draft.id);
          return Success(value);
        }
      }
      attempt.superseded = true; // the hung one may still finish later
      attempt = null;
      replaced = true;
    }
    if (attempt == null) {
      final fresh = _Attempt()..supersededOther = replaced;
      attempt = fresh;
      _inFlight[draft.id] = fresh;
      fresh.result = _save(draft, request, onPhase, fresh);
      unawaited(
        fresh.result
            .whenComplete(() {
              if (identical(_inFlight[draft.id], fresh)) {
                _inFlight.remove(draft.id);
              }
            })
            .then((_) {}),
      );
    }
    final current = attempt;
    final result = await current.result.timeout(
      attemptTimeout,
      onTimeout: () {
        current.timedOut = true;
        return const Failed(TimeoutFailure());
      },
    );
    return result;
  }

  /// True while an attempt for [draftId] is still running (after a timeout
  /// the user may be told it is still going).
  bool isSaving(String draftId) => _inFlight.containsKey(draftId);

  /// The operation identity: the same owner, draft and audio CONTENT always
  /// give the same story id and path, also after an app restart (nothing to
  /// persist), and any change to the audio gives a different one, so an old
  /// upload can never be bound to a new recording.
  static String stableStoryId(
    String ownerId,
    String draftId,
    String audioSha256,
  ) {
    final d = sha256.convert(utf8.encode('$ownerId:$draftId:$audioSha256'));
    final b = d.bytes.sublist(0, 16);
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  static bool _sameSet(Iterable<String> a, Iterable<String> b) =>
      a.toSet().length == b.toSet().length && a.toSet().containsAll(b);

  static bool _isThisStory(Story stored, Story wanted, String uid) =>
      stored.createdBy == uid &&
      stored.spaceId == wanted.spaceId &&
      stored.audioPath == wanted.audioPath &&
      stored.visibility == wanted.visibility &&
      stored.title == wanted.title &&
      stored.description == wanted.description &&
      stored.topic == wanted.topic &&
      stored.approxDateLabel == wanted.approxDateLabel &&
      stored.approxYear == wanted.approxYear &&
      stored.durationSeconds == wanted.durationSeconds;

  /// Whether a stored story carries the joins the request asked for.
  static bool _joinsMatch(Story stored, Story wanted) =>
      _sameSet(stored.narratorIds, wanted.narratorIds) &&
      _sameSet(stored.peopleIds, wanted.peopleIds) &&
      _sameSet(stored.photoIds, wanted.photoIds) &&
      (wanted.visibility != StoryVisibility.selected ||
          _sameSet(stored.recipientUserIds, wanted.recipientUserIds));

  /// A failure after which the write may still land (late completion).
  static bool _uncertain(AppFailure f) =>
      f is TimeoutFailure || f is NetworkFailure || f is UnknownFailure;

  Future<Result<Story>> _save(
    StoryDraft draft,
    StorySaveRequest request,
    void Function(SavePhase phase)? onPhase,
    _Attempt attempt,
  ) async {
    void phase(SavePhase p) {
      if (!attempt.superseded) onPhase?.call(p);
    }

    final uid = userId;
    if (uid == null) return const Failed(UnauthorizedFailure());
    phase(SavePhase.preparing);
    final FamilySpace? space;
    switch (await family.getMySpace()) {
      case Success(:final value):
        space = value;
      case Failed(:final failure):
        return Failed(failure);
    }
    if (space == null) return const Failed(NotFoundFailure());

    final String joined;
    try {
      joined = await joinTake(draft);
    } on Exception catch (e) {
      return Failed(AppFailure.from(e));
    }
    final int bytes;
    final String digest;
    try {
      final file = File(joined);
      bytes = await file.length();
      digest = (await sha256.bind(file.openRead()).first).toString();
    } on Exception catch (e) {
      return Failed(AppFailure.from(e));
    }
    final storyId = _fixedId?.call() ?? stableStoryId(uid, draft.id, digest);
    attempt.storyId = storyId;

    final ext = joined.endsWith('.wav') ? 'wav' : 'm4a';
    // Namespaced by uploader: the storage insert policy rejects any write
    // outside your own prefix.
    final storagePath = '${space.id}/$uid/$storyId/a.$ext';

    final story = Story(
      id: storyId,
      spaceId: space.id,
      title: request.title.trim(),
      description: request.description.trim().isEmpty
          ? null
          : request.description.trim(),
      topic: request.topic ?? draft.topic,
      approxDateLabel: request.dateLabel.trim().isEmpty
          ? null
          : request.dateLabel.trim(),
      approxYear: request.year,
      visibility: request.visibility,
      audioPath: storagePath,
      durationSeconds: draft.durationSeconds,
      createdBy: '',
      createdAt: DateTime.now(),
      narratorIds: request.narratorIds,
      peopleIds: request.peopleIds,
      recipientUserIds: request.visibility == StoryVisibility.selected
          ? request.recipientUserIds
          : const [],
      photoIds: request.photoIds,
      waveform: request.waveform,
    );
    // An earlier attempt (before a restart, or one that timed out and then
    // finished) may already have created this story: use it, change nothing.
    final already = await stories.getStory(storyId);
    if (already case Success<Story?>(:final value?)) {
      // The row can exist while its joins (narrators, people, photos,
      // recipients) are missing after an interrupted create. When it is this
      // exact pending story (same owner, space, audio and metadata), only
      // the missing joins are added; nothing is deleted or overwritten. A
      // story that differs was changed since: leave it alone.
      if (_isThisStory(value, story, uid) && !_joinsMatch(value, story)) {
        final done = await stories.createStory(story);
        if (done is Failed<Story>) return done;
        if (!attempt.superseded) await drafts.delete(draft.id);
        return done;
      }
      if (!attempt.superseded) await drafts.delete(draft.id);
      return Success(value);
    }

    phase(SavePhase.uploading);
    switch (await stories.uploadAudio(joined, storagePath)) {
      case Failed(:final failure):
        // The failure may be a duplicate (an earlier attempt stored it) or a
        // real error. Reuse an existing object only when it is verifiably
        // this audio: same content-derived path, same size. Otherwise fail
        // and bind nothing.
        final stored = await stories.audioSize(storagePath);
        final same = stored is Success<int?> && stored.value == bytes;
        if (!same) return Failed(failure);
      case Success():
        break;
    }

    phase(SavePhase.creating);
    final created = await stories.createStory(story);
    if (created is Failed<Story>) {
      // The row may exist even though the call failed (a late write, or a
      // duplicate id from an earlier attempt): look before concluding.
      final existing = await stories.getStory(storyId);
      if (existing case Success<Story?>(:final value?)) {
        if (_isThisStory(value, story, uid) && !_joinsMatch(value, story)) {
          return created;
        }
        if (!attempt.superseded) await drafts.delete(draft.id);
        return Success(value);
      }
      // Remove the upload only when the failure is a definite rejection and
      // the story does not exist. After an uncertain failure the audio stays
      // so a retry reuses it and a late-created story keeps its audio.
      // Never while this attempt was replaced or replaced another: a second
      // attempt may be using the same object.
      // An unauthorized answer is ambiguous (a lapsed session looks the same
      // as a policy refusal), so the upload stays for the retry.
      if (!_uncertain(created.failure) &&
          created.failure is! UnauthorizedFailure &&
          existing is Success<Story?> &&
          !attempt.superseded &&
          !attempt.supersededOther) {
        await stories.deleteAudio(storagePath);
      }
      return created;
    }
    if (!attempt.superseded) await drafts.delete(draft.id);
    return created;
  }
}

Future<String> _joinTake(StoryDraft draft) {
  final first = draft.segments.isEmpty ? '' : draft.segments.first.path;
  if (draft.segments.length == 1 && !first.endsWith('.wav')) {
    return Future.value(first);
  }
  return SegmentJoiner.join(
    draft.segments,
    '${File(first).parent.path}/story.wav',
  );
}

class _Attempt {
  late Future<Result<Story>> result;
  String? storyId;
  bool timedOut = false;

  /// A newer attempt replaced this one: it must not touch the draft, the
  /// shared audio or the UI.
  bool superseded = false;

  /// This attempt replaced a hung one that may still be writing.
  bool supersededOther = false;
}
