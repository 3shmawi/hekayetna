import 'dart:async';

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/analytics/analytics.dart';
import 'package:family_stories/core/network/app_failure.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/core/router/app_routes.dart';
import 'package:family_stories/core/widgets/state_views.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/player/audio_player_controller.dart';
import 'package:family_stories/features/stories/presentation/story_providers.dart';
import 'package:family_stories/features/stories/presentation/story_screens.dart';
import 'package:family_stories/features/stories/presentation/story_sheets.dart';
import 'package:family_stories/features/stories/presentation/story_view.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// One story: loads it through [storyProvider] and hands plain values to
/// [StoryView]. Playback goes through the app-wide player controller.
class StoryPage extends ConsumerWidget {
  const StoryPage({required this.storyId, super.key});

  final String storyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final story = ref.watch(storyProvider(storyId));
    final value = story.value;
    if (value != null) return _Loaded(story: value);
    if (story.isLoading) return const StoryStateView.loading();
    if (story.hasError) {
      return StoryStateView.error(
        failure: AppFailure.from(story.error!),
        onRetry: () => ref.invalidate(storyProvider(storyId)),
      );
    }
    // Missing or not shared: the backend does not say which, on purpose.
    return const StoryStateView.notShared();
  }
}

class _Loaded extends ConsumerWidget {
  const _Loaded({required this.story});

  final Story story;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.l10n;
    final space = ref.watch(currentSpaceProvider).value;
    final persons = space == null
        ? const <Person>[]
        : ref.watch(personsProvider(space.id)).value ?? const <Person>[];
    final members = space == null
        ? const <FamilyMember>[]
        : ref.watch(membersProvider(space.id)).value ?? const <FamilyMember>[];
    final player = ref.watch(audioPlayerControllerProvider);
    final controller = ref.read(audioPlayerControllerProvider.notifier);
    final me = ref.watch(currentUserIdProvider);

    String? nameOf(String id) {
      for (final p in persons) {
        if (p.id == id) return p.fullName;
      }
      return null;
    }

    final narrator = story.narratorIds.map(nameOf).whereType<String>();
    String? recordedBy;
    for (final m in members) {
      if (m.userId == story.createdBy) recordedBy = m.displayName;
    }

    String note(StoryVisibility v) => switch (v) {
      StoryVisibility.private => s.storyVisPrivate,
      StoryVisibility.family => s.storyVisFamily('${members.length}'),
      StoryVisibility.selected => s.storyVisSelected(
        '${story.recipientUserIds.length}',
        [
          for (final m in members)
            if (story.recipientUserIds.contains(m.userId)) m.displayName,
        ].join(', '),
      ),
    };

    return StoryView(
      story: story,
      player: player,
      narratorName: narrator.isEmpty ? s.feedNarratorFallback : narrator.first,
      recordedBy: recordedBy == null ? null : s.storyRecordedBy(recordedBy),
      isCreator: me != null && me == story.createdBy,
      visibilityNote: note(story.visibility),
      people: [
        for (final p in persons)
          if (story.peopleIds.contains(p.id)) p,
      ],
      photos: story.photoIds.isEmpty
          ? null
          : StoryPhotosGrid(photoIds: story.photoIds),
      onToggle: () => unawaited(
        player.storyId == story.id
            ? controller.toggle()
            : controller.playStory(story),
      ),
      onSeek: (to) {
        if (player.storyId == story.id) unawaited(controller.seek(to));
      },
      onSpeed: () {
        final i = playbackSpeeds.indexOf(player.speed);
        unawaited(
          controller.setSpeed(playbackSpeeds[(i + 1) % playbackSpeeds.length]),
        );
      },
      onMenu: (action) => switch (action) {
        StoryMenuAction.edit => _edit(context, ref),
        StoryMenuAction.whoCanListen => _visibility(context, ref, note),
        StoryMenuAction.delete => _delete(context, ref),
      },
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final edited = await showEditDetailsSheet(context, story);
    if (edited == null || !context.mounted) return;
    await _save(context, ref, edited);
  }

  Future<void> _visibility(
    BuildContext context,
    WidgetRef ref,
    String Function(StoryVisibility) note,
  ) async {
    final next = await showVisibilitySheet(
      context,
      current: story.visibility,
      consequence: note,
    );
    if (next == null || !context.mounted) return;
    await _save(context, ref, story.copyWith(visibility: next));
  }

  Future<void> _save(BuildContext context, WidgetRef ref, Story next) async {
    final result = await ref.read(storyActionsProvider).updateStory(next);
    if (!context.mounted) return;
    if (result case Failed(:final failure)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message(context.l10n))));
    } else {
      unawaited(Analytics.capture('story_edited'));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    if (!await confirmDeleteStory(context) || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final router = GoRouter.of(context);
    final result = await ref.read(storyActionsProvider).deleteStory(story);
    switch (result) {
      case Failed(:final failure):
        messenger.showSnackBar(SnackBar(content: Text(failure.message(l10n))));
      case Success():
        unawaited(Analytics.capture('story_deleted'));
        if (ref.read(audioPlayerControllerProvider).storyId == story.id) {
          await ref.read(audioPlayerControllerProvider.notifier).stop();
        }
        messenger.showSnackBar(SnackBar(content: Text(l10n.storyDeleted)));
        router.go(AppRoutes.stories);
    }
  }
}
