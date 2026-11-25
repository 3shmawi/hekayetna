import 'dart:async';

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/analytics/analytics.dart';
import 'package:family_stories/core/network/app_failure.dart';
import 'package:family_stories/core/router/app_routes.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/core/widgets/state_views.dart';
import 'package:family_stories/features/stories/data/story_repository.dart';
import 'package:family_stories/features/stories/player/audio_player_controller.dart';
import 'package:family_stories/features/stories/presentation/feed_filters.dart';
import 'package:family_stories/features/stories/presentation/no_space_view.dart';
import 'package:family_stories/features/stories/presentation/story_feed_view.dart';
import 'package:family_stories/features/stories/presentation/story_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Home: reads the space and the feed from providers and hands plain values
/// to [StoryFeedView]. Rebuilding never refetches; only pull-to-refresh and
/// Retry do.
class StoryFeedPage extends ConsumerStatefulWidget {
  const StoryFeedPage({super.key});

  @override
  ConsumerState<StoryFeedPage> createState() => _StoryFeedPageState();
}

class _StoryFeedPageState extends ConsumerState<StoryFeedPage> {
  var _selection = const FeedSelection();

  @override
  Widget build(BuildContext context) {
    ref.listen(feedNarratorRequestProvider, (_, id) {
      if (id == null) return;
      setState(() => _selection = FeedSelection(narratorId: id));
      ref.read(feedNarratorRequestProvider.notifier).request(null);
    });
    final space = ref.watch(currentSpaceProvider);
    final notifier = ref.read(currentSpaceProvider.notifier);
    return switch (space) {
      AsyncData(value: null) => AppScaffold(
        body: NoSpaceView(
          onCreate: notifier.createSpace,
          onJoin: notifier.joinSpace,
        ),
      ),
      AsyncData(value: final s?) => _feed(s.id),
      AsyncError(:final error) => AppScaffold(
        body: ErrorView(
          failure: AppFailure.from(error),
          onRetry: notifier.refresh,
        ),
      ),
      _ => const AppScaffold(body: LoadingView()),
    };
  }

  Widget _feed(String spaceId) {
    final feed = storyFeedProvider(_selection.toFilter());
    // Chips come from the unfiltered list, so they stay while one is on.
    final all = ref.watch(storyFeedProvider(const StoryFilter()));
    final persons = ref.watch(personsProvider(spaceId)).value ?? const [];
    final options = FeedFilterOptions.from(all.value ?? const [], persons);
    return StoryFeedView(
      stories: ref.watch(feed),
      options: options,
      selection: _selection,
      narratorNames: {for (final p in persons) p.id: p.fullName},
      isDemo: ref.watch(isDemoModeProvider),
      onSelectionChanged: (next) {
        setState(() => _selection = next);
        unawaited(
          Analytics.capture('story_feed_filtered', {
            'narrator': next.narratorId != null,
            'topic': next.topic != null,
            'decade': next.decade != null,
          }),
        );
      },
      onRefresh: () async {
        await ref.read(feed.notifier).refresh();
        if (!_selection.isAll) {
          await ref
              .read(storyFeedProvider(const StoryFilter()).notifier)
              .refresh();
        }
      },
      onRetry: () => ref.invalidate(feed),
      onOpen: (story) {
        unawaited(Analytics.capture('story_opened'));
        unawaited(context.push(AppRoutes.storyDetail(story.id)));
      },
      onPlay: (story) =>
          ref.read(audioPlayerControllerProvider.notifier).playStory(story),
      onRecord: () => context.go(AppRoutes.record),
      onAccount: () => context.push('/settings'),
    );
  }
}
