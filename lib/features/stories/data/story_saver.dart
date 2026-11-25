import 'dart:async';
import 'dart:io';

import 'package:family_stories/core/network/app_failure.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/features/family/data/family_repository.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/recording/data/draft_store.dart';
import 'package:family_stories/features/recording/data/segment_joiner.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/data/story_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show StorageException;

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

  final _inFlight = <String, Future<Result<Story>>>{};

  /// Saves the take. One attempt per draft runs at a time: a second call
  /// (a retry after a timeout, a double tap) joins the running attempt, so
  /// two writes of the same take never race. After [attemptTimeout] this
  /// returns [TimeoutFailure] while the attempt keeps running; calling again
  /// waits for it, and if it already finished returns its real result.
  Future<Result<Story>> save(
    StoryDraft draft,
    StorySaveRequest request, {
    void Function(SavePhase phase)? onPhase,
  }) async {
    var attempt = _inFlight[draft.id];
    if (attempt == null) {
      attempt = _save(draft, request, onPhase);
      _inFlight[draft.id] = attempt;
      unawaited(
        attempt.whenComplete(() => _inFlight.remove(draft.id)).then((_) {}),
      );
    }
    final result = await attempt.timeout(
      attemptTimeout,
      onTimeout: () => const Failed(TimeoutFailure()),
    );
    return result;
  }

  /// True while an attempt for [draftId] is still running (after a timeout
  /// the user may be told it is still going).
  bool isSaving(String draftId) => _inFlight.containsKey(draftId);

  /// Same draft and same audio always give the same story id and path, also
  /// after the app restarts, so a retry finds what an earlier attempt
  /// already stored instead of writing a second copy.
  static String stableStoryId(String draftId, int audioBytes) {
    int fnv(String text, int seed) {
      var h = seed;
      for (final c in text.codeUnits) {
        h = ((h ^ c) * 16777619) & 0xffffffff;
      }
      return h;
    }

    final key = '$draftId:$audioBytes';
    final h = [
      for (final seed in [0x811c9dc5, 0x9747b28c, 0x3c6ef372, 0xa54ff53a])
        fnv(key, seed).toRadixString(16).padLeft(8, '0'),
    ].join();
    final variant = (int.parse(h[16], radix: 16) & 0x3) | 0x8;
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-4${h.substring(13, 16)}-'
        '${variant.toRadixString(16)}${h.substring(17, 20)}-${h.substring(20)}';
  }

  static bool _duplicateObject(AppFailure f) {
    final cause = f.cause;
    return cause is StorageException &&
        (cause.statusCode == '409' || cause.statusCode == '400') &&
        cause.message.toLowerCase().contains('exist');
  }

  /// A failure after which the write may still land (late completion).
  static bool _uncertain(AppFailure f) =>
      f is TimeoutFailure || f is NetworkFailure || f is UnknownFailure;

  Future<Result<Story>> _save(
    StoryDraft draft,
    StorySaveRequest request,
    void Function(SavePhase phase)? onPhase,
  ) async {
    final uid = userId;
    if (uid == null) return const Failed(UnauthorizedFailure());
    onPhase?.call(SavePhase.preparing);
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
    var bytes = 0;
    try {
      bytes = File(joined).lengthSync();
    } on FileSystemException {
      // unreadable size: the id then depends on the draft alone
    }
    final storyId = _fixedId?.call() ?? stableStoryId(draft.id, bytes);

    // An earlier attempt (before a restart, or one that timed out and then
    // finished) may already have created this story: use it, change nothing.
    final already = await stories.getStory(storyId);
    if (already case Success<Story?>(:final value?)) {
      await drafts.delete(draft.id);
      return Success(value);
    }

    final ext = joined.endsWith('.wav') ? 'wav' : 'm4a';
    // Namespaced by uploader: the storage insert policy rejects any write
    // outside your own prefix.
    final storagePath = '${space.id}/$uid/$storyId/a.$ext';

    onPhase?.call(SavePhase.uploading);
    switch (await stories.uploadAudio(joined, storagePath)) {
      case Failed(:final failure):
        // The object already there is this draft's own earlier upload (path
        // = space/uploader/story id, which only this draft's audio maps to).
        // Storage writes appear whole, so it is kept and used, never
        // deleted or overwritten.
        if (!_duplicateObject(failure)) return Failed(failure);
      case Success():
        break;
    }

    onPhase?.call(SavePhase.creating);
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
    final created = await stories.createStory(story);
    if (created is Failed<Story>) {
      // The row may exist even though the call failed (a late write, or a
      // duplicate id from an earlier attempt): look before concluding.
      final existing = await stories.getStory(storyId);
      if (existing case Success<Story?>(:final value?)) {
        await drafts.delete(draft.id);
        return Success(value);
      }
      // Remove the upload only when the failure is a definite rejection and
      // the story does not exist. After an uncertain failure the audio stays
      // so a retry reuses it and a late-created story keeps its audio.
      if (!_uncertain(created.failure) && existing is Success<Story?>) {
        await stories.deleteAudio(storagePath);
      }
      return created;
    }
    await drafts.delete(draft.id);
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
