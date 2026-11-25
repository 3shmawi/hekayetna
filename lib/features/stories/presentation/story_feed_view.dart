import 'package:family_stories/core/adaptive/adaptive.dart';
import 'package:family_stories/core/network/app_failure.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/core/widgets/state_views.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/domain/story_topics.dart';
import 'package:family_stories/features/stories/presentation/feed_filters.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The stories feed, drawn from plain values so tests and goldens can
/// render every state without a backend.
class StoryFeedView extends StatelessWidget {
  const StoryFeedView({
    required this.stories,
    required this.options,
    required this.selection,
    required this.narratorNames,
    required this.onSelectionChanged,
    required this.onRefresh,
    required this.onOpen,
    required this.onPlay,
    required this.onRecord,
    this.isDemo = false,
    this.onAccount,
    this.onRetry,
    this.questionSlot,
    super.key,
  });

  /// Loading shows skeletons, an error shows Retry, data shows the cards.
  final AsyncValue<List<Story>> stories;
  final FeedFilterOptions options;
  final FeedSelection selection;

  /// Person id to display name, for the cards.
  final Map<String, String> narratorNames;
  final ValueChanged<FeedSelection> onSelectionChanged;
  final Future<void> Function() onRefresh;
  final ValueChanged<Story> onOpen;
  final ValueChanged<Story> onPlay;
  final VoidCallback onRecord;
  final bool isDemo;
  final VoidCallback? onAccount;
  final VoidCallback? onRetry;

  /// Spec 07 fills this with the question-of-the-week card.
  final Widget? questionSlot;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return AppScaffold(
      title: s.stories,
      actions: [
        if (onAccount != null)
          AppIconButton(
            // The integration tests open Settings through this key.
            key: const Key('home_settings_button'),
            // It opens Settings, so icon and label say Settings (the
            // Account row lives inside).
            icon: AdaptiveIcons.settings(context),
            tooltip: s.settingsTitle,
            onPressed: onAccount!,
          ),
      ],
      body: Column(
        children: [
          if (isDemo) _DemoBand(text: s.demoMode),
          if (!options.isEmpty || !selection.isAll)
            _FilterRow(
              options: options,
              selection: selection,
              onChanged: onSelectionChanged,
            ),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    // A refresh that fails keeps the list on screen (the value survives).
    final data = stories.value;
    return switch (stories) {
      _ when data != null => _list(context, data),
      AsyncLoading() => ListView(
        padding: EdgeInsets.all(AppDimens.lg),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < 4; i++) ...[
            const SkeletonCard(),
            SizedBox(height: AppDimens.md),
          ],
        ],
      ),
      AsyncError(:final error) => ErrorView(
        failure: AppFailure.from(error),
        onRetry: onRetry,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _list(BuildContext context, List<Story> value) {
    final s = context.l10n;
    if (value.isEmpty) {
      return selection.isAll
          ? EmptyView(
              title: s.noStoriesTitle,
              message: s.noStoriesBody,
              actionLabel: s.feedRecordFirst,
              onAction: onRecord,
              icon: AdaptiveIcons.stories(context),
            )
          : EmptyView(
              message: s.noStoriesBody,
              icon: AdaptiveIcons.stories(context),
            );
    }
    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(AppDimens.lg),
        children: [
          ?questionSlot,
          if (questionSlot != null) SizedBox(height: AppDimens.lg),
          AppSectionLabel(s.feedRecentlyAdded),
          SizedBox(height: AppDimens.md),
          for (final story in value) ...[
            StoryCard(
              title: story.title,
              narratorName: _narrator(story, s.feedNarratorFallback),
              dateLabel: story.approxDateLabel,
              duration: _duration(story),
              topicLabel: story.topic == null
                  ? null
                  : topicLabel(s, story.topic!),
              isSample: isDemo,
              onOpen: () => onOpen(story),
              onPlay: () => onPlay(story),
            ),
            SizedBox(height: AppDimens.md),
          ],
        ],
      ),
    );
  }

  String _narrator(Story story, String fallback) {
    for (final id in story.narratorIds) {
      final name = narratorNames[id];
      if (name != null) return name;
    }
    return fallback;
  }

  static String _duration(Story story) {
    final m = story.durationSeconds ~/ 60;
    final sec = (story.durationSeconds % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }
}

/// A horizontal, scrollable row that never wraps: All, narrators, topics,
/// decades.
class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.options,
    required this.selection,
    required this.onChanged,
  });

  final FeedFilterOptions options;
  final FeedSelection selection;
  final ValueChanged<FeedSelection> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final chips = <Widget>[
      AppChip(
        label: s.feedFilterAll,
        selected: selection.isAll,
        onTap: () => onChanged(const FeedSelection()),
      ),
      for (final p in options.narrators)
        AppChip(
          label: p.fullName,
          selected: selection.narratorId == p.id,
          onTap: () => onChanged(selection.toggleNarrator(p.id)),
        ),
      for (final t in options.topics)
        AppChip(
          label: topicLabel(s, t),
          selected: selection.topic == t,
          onTap: () => onChanged(selection.toggleTopic(t)),
        ),
      for (final d in options.decades)
        AppChip(
          label: s.feedDecade('$d'),
          selected: selection.decade == d,
          onTap: () => onChanged(selection.toggleDecade(d)),
        ),
    ];
    return Semantics(
      container: true,
      label: s.feedFiltersLabel,
      child: SizedBox(
        height: AppDimens.targetMin + AppDimens.md,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: AppDimens.lg),
          itemCount: chips.length,
          separatorBuilder: (_, _) => SizedBox(width: AppDimens.sm),
          itemBuilder: (_, i) => Center(child: chips[i]),
        ),
      ),
    );
  }
}

class _DemoBand extends StatelessWidget {
  const _DemoBand({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final hk = context.hk;
    return Container(
      width: double.infinity,
      color: hk.goldTint,
      padding: EdgeInsets.symmetric(
        horizontal: AppDimens.lg,
        vertical: AppDimens.sm,
      ),
      child: Text(text, style: AppTextStyles.caption.copyWith(color: hk.gold)),
    );
  }
}
