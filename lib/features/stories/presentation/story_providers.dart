import 'dart:async';

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/monitoring/monitoring.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/photos/data/models.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/data/story_repository.dart';
import 'package:family_stories/features/stories/data/story_saver.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The family space of the signed-in user, fetched once and cached.
/// `null` data means the user has no space yet (create or join one).
final currentSpaceProvider =
    AsyncNotifierProvider<CurrentSpaceNotifier, FamilySpace?>(
      CurrentSpaceNotifier.new,
    );

class CurrentSpaceNotifier extends AsyncNotifier<FamilySpace?> {
  @override
  Future<FamilySpace?> build() async =>
      (await ref.watch(familyRepositoryProvider).getMySpace()).unwrap();

  /// Reloads from the backend, keeping the old value on screen meanwhile.
  Future<void> refresh() async {
    final result = await ref.read(familyRepositoryProvider).getMySpace();
    state = switch (result) {
      Success(:final value) => AsyncData(value),
      Failed(:final failure) => AsyncError(failure, StackTrace.current),
    };
  }

  Future<Result<FamilySpace>> createSpace(String name) async {
    final result = await ref.read(familyRepositoryProvider).createSpace(name);
    if (result case Success(:final value)) state = AsyncData(value);
    return result;
  }

  Future<Result<FamilySpace>> joinSpace(String inviteCode) async {
    final result = await ref
        .read(familyRepositoryProvider)
        .joinSpace(inviteCode);
    if (result case Success(:final value)) state = AsyncData(value);
    return result;
  }
}

/// People of a space, for narrator names and filter chips.
// ignore: specify_nonobvious_property_types
final personsProvider = FutureProvider.family<List<Person>, String>(
  (ref, spaceId) async =>
      (await ref.watch(familyRepositoryProvider).listPersons(spaceId)).unwrap(),
);

/// Photos of a space the member can see, for linking to a story.
// ignore: specify_nonobvious_property_types
final spacePhotosProvider = FutureProvider.family<List<Photo>, String>(
  (ref, spaceId) async =>
      (await ref.watch(photoRepositoryProvider).listPhotos(spaceId)).unwrap(),
);

/// Members of a space, for "Recorded by" and the visibility note.
// ignore: specify_nonobvious_property_types
final membersProvider = FutureProvider.family<List<FamilyMember>, String>(
  (ref, spaceId) async =>
      (await ref.watch(familyRepositoryProvider).listMembers(spaceId)).unwrap(),
);

/// Stories of the current space for one filter. Built once per filter and
/// kept: rebuilding a widget never refetches, only [StoryFeedNotifier.refresh].
// ignore: specify_nonobvious_property_types
final storyFeedProvider =
    AsyncNotifierProvider.family<StoryFeedNotifier, List<Story>, StoryFilter>(
      StoryFeedNotifier.new,
    );

class StoryFeedNotifier extends AsyncNotifier<List<Story>> {
  StoryFeedNotifier(this.filter);

  final StoryFilter filter;

  @override
  Future<List<Story>> build() => _load();

  Future<List<Story>> _load() async {
    final space = await ref.watch(currentSpaceProvider.future);
    if (space == null) return const [];
    final result = await ref
        .read(storyRepositoryProvider)
        .listStories(space.id, filter: filter);
    return result.unwrap();
  }

  /// Pull-to-refresh. A failed refresh keeps the list that is on screen
  /// and reports the failure as the new state.
  Future<void> refresh() async {
    final space = ref.read(currentSpaceProvider).value;
    if (space == null) return;
    final result = await ref
        .read(storyRepositoryProvider)
        .listStories(space.id, filter: filter);
    state = switch (result) {
      Success(:final value) => AsyncData(value),
      Failed(:final failure) => AsyncError(failure, StackTrace.current),
    };
  }
}

/// One story. `null` data: it doesn't exist or the member may not see it
/// (the backend does not say which, on purpose).
// ignore: specify_nonobvious_property_types
final storyProvider =
    AsyncNotifierProvider.family<StoryNotifier, Story?, String>(
      StoryNotifier.new,
    );

class StoryNotifier extends AsyncNotifier<Story?> {
  StoryNotifier(this.storyId);

  final String storyId;

  @override
  Future<Story?> build() async =>
      (await ref.watch(storyRepositoryProvider).getStory(storyId)).unwrap();

  Future<void> refresh() async {
    final result = await ref.read(storyRepositoryProvider).getStory(storyId);
    state = switch (result) {
      Success(:final value) => AsyncData(value),
      Failed(:final failure) => AsyncError(failure, StackTrace.current),
    };
  }
}

/// Story changes the screens trigger. Each one refreshes the feed lists.
final storyActionsProvider = Provider<StoryActions>(StoryActions.new);

class StoryActions {
  StoryActions(this._ref);

  final Ref _ref;

  /// Deletes the row first, then the audio object. If the object delete
  /// fails the file is unreachable anyway (its read policy needs the row),
  /// so the failure goes to monitoring and the user sees success.
  Future<Result<void>> deleteStory(Story story) async {
    final repo = _ref.read(storyRepositoryProvider);
    final deleted = await repo.deleteStory(story.id);
    if (deleted is Failed<void>) return deleted;
    final audio = await repo.deleteAudio(story.audioPath);
    if (audio case Failed(:final failure)) {
      unawaited(
        Monitoring.captureException(
          failure.cause ?? failure,
          StackTrace.current,
        ),
      );
    }
    _ref
      ..invalidate(storyFeedProvider)
      ..invalidate(storyProvider(story.id));
    return const Success(null);
  }

  Future<Result<Story>> updateStory(Story story) async {
    final result = await _ref.read(storyRepositoryProvider).updateStory(story);
    if (result is Success<Story>) {
      _ref
        ..invalidate(storyFeedProvider)
        ..invalidate(storyProvider(story.id));
    }
    return result;
  }
}

/// Builds the [StorySaver] for the signed-in user. Tests override it to
/// skip joining audio files.
final storySaverProvider = Provider<StorySaver>(
  (ref) => StorySaver(
    stories: ref.watch(storyRepositoryProvider),
    family: ref.watch(familyRepositoryProvider),
    drafts: ref.watch(draftStoreProvider),
    userId: ref.watch(currentUserIdProvider),
  ),
);

/// A person whose stories the feed should show next (set by the family
/// tree's "See all"). The feed page reads it once and clears it.
final feedNarratorRequestProvider =
    NotifierProvider<FeedNarratorRequest, String?>(FeedNarratorRequest.new);

class FeedNarratorRequest extends Notifier<String?> {
  @override
  String? build() => null;

  // A setter-style method is the Notifier convention.
  // ignore: use_setters_to_change_properties
  void request(String? personId) => state = personId;
}
