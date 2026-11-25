import 'dart:io';

import 'package:family_stories/core/ids.dart';
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
  }) : _newId = newId ?? newUuid;

  final StoryRepository stories;
  final FamilyRepository family;
  final DraftStore drafts;
  final String? userId;
  final Future<String> Function(StoryDraft draft) joinTake;
  final String Function() _newId;

  Future<Result<Story>> save(
    StoryDraft draft,
    StorySaveRequest request, {
    void Function(SavePhase phase)? onPhase,
  }) async {
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
    final storyId = _newId();
    final ext = joined.endsWith('.wav') ? 'wav' : 'm4a';
    // Namespaced by uploader: the storage insert policy rejects any write
    // outside your own prefix.
    final storagePath = '${space.id}/$uid/$storyId/a.$ext';

    onPhase?.call(SavePhase.uploading);
    switch (await stories.uploadAudio(joined, storagePath)) {
      case Failed(:final failure):
        return Failed(failure);
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
      // The take is in the bucket but no story points at it: remove it so
      // failed saves leave nothing behind. A cleanup failure is not shown.
      await stories.deleteAudio(storagePath);
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
