import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/network/app_failure.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/features/family/data/demo_family_repository.dart';
import 'package:family_stories/features/stories/data/demo_story_repository.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/data/story_repository.dart';
import 'package:family_stories/features/stories/presentation/story_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingStories extends DemoStoryRepository {
  int listCalls = 0;
  final calls = <String>[];
  bool failAudioDelete = false;
  bool failRowDelete = false;

  @override
  Future<Result<List<Story>>> listStories(
    String spaceId, {
    StoryFilter? filter,
  }) async {
    listCalls++;
    return await super.listStories(spaceId, filter: filter);
  }

  @override
  Future<Result<void>> deleteStory(String storyId) async {
    calls.add('row');
    if (failRowDelete) return const Failed(NetworkFailure());
    return await super.deleteStory(storyId);
  }

  @override
  Future<Result<void>> deleteAudio(String storagePath) async {
    calls.add('audio');
    if (failAudioDelete) return const Failed(ServerFailure());
    return await super.deleteAudio(storagePath);
  }
}

void main() {
  late _CountingStories stories;
  late ProviderContainer container;

  setUp(() {
    stories = _CountingStories();
    container = ProviderContainer(
      overrides: [
        familyRepositoryProvider.overrideWithValue(DemoFamilyRepository()),
        storyRepositoryProvider.overrideWithValue(stories),
      ],
    );
    addTearDown(container.dispose);
  });

  test('the feed loads once however often it is read (AC-2)', () async {
    const filter = StoryFilter();
    final sub = container.listen(storyFeedProvider(filter), (_, _) {});
    await container.read(storyFeedProvider(filter).future);
    container
      ..read(storyFeedProvider(filter))
      ..read(storyFeedProvider(filter));
    await container.read(storyFeedProvider(filter).future);
    expect(stories.listCalls, 1);
    sub.close();
  });

  test('refresh fetches again and keeps the list', () async {
    const filter = StoryFilter();
    container.listen(storyFeedProvider(filter), (_, _) {});
    final first = await container.read(storyFeedProvider(filter).future);
    await container.read(storyFeedProvider(filter).notifier).refresh();
    expect(stories.listCalls, 2);
    expect(
      container.read(storyFeedProvider(filter)).value,
      hasLength(first.length),
    );
  });

  test('equal filters share one feed', () async {
    container
      ..listen(storyFeedProvider(const StoryFilter(topic: 'a')), (_, _) {})
      ..listen(storyFeedProvider(const StoryFilter(topic: 'a')), (_, _) {});
    await container.read(
      storyFeedProvider(const StoryFilter(topic: 'a')).future,
    );
    expect(stories.listCalls, 1);
  });

  test('delete removes the row, then the file', () async {
    container.listen(storyFeedProvider(const StoryFilter()), (_, _) {});
    final list = await container.read(
      storyFeedProvider(const StoryFilter()).future,
    );
    final result = await container
        .read(storyActionsProvider)
        .deleteStory(list.first);
    expect(result, isA<Success<void>>());
    expect(stories.calls, ['row', 'audio']);
  });

  test('a failed file delete is not shown to the user', () async {
    stories.failAudioDelete = true;
    final list = await container.read(
      storyFeedProvider(const StoryFilter()).future,
    );
    final result = await container
        .read(storyActionsProvider)
        .deleteStory(list.first);
    expect(result, isA<Success<void>>());
  });

  test('a failed row delete fails and leaves the file alone', () async {
    stories.failRowDelete = true;
    final list = await container.read(
      storyFeedProvider(const StoryFilter()).future,
    );
    final result = await container
        .read(storyActionsProvider)
        .deleteStory(list.first);
    expect(result, isA<Failed<void>>());
    expect(stories.calls, ['row']);
  });

  test('current space is cached', () async {
    final a = await container.read(currentSpaceProvider.future);
    final b = await container.read(currentSpaceProvider.future);
    expect(identical(a, b) || a?.id == b?.id, isTrue);
  });
}
