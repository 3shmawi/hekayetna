import 'package:family_stories/core/network/app_failure.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/core/ui/app_ui.dart' hide StoryVisibility;
import 'package:family_stories/core/widgets/state_views.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/domain/story_topics.dart';
import 'package:family_stories/features/stories/player/audio_player_controller.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// What the member does from the story page's "More" menu.
enum StoryMenuAction { edit, whoCanListen, delete }

/// The story page, drawn from plain values so every state can be tested
/// and captured without a backend.
class StoryView extends StatelessWidget {
  const StoryView({
    required this.story,
    required this.player,
    required this.narratorName,
    required this.isCreator,
    required this.visibilityNote,
    required this.onToggle,
    required this.onSeek,
    required this.onSpeed,
    required this.onMenu,
    this.recordedBy,
    this.people = const [],
    this.photos,
    this.onPersonTap,
    super.key,
  });

  final Story story;

  /// The app-wide player state; only used while it holds this story.
  final PlayerState player;
  final String narratorName;
  final String? recordedBy;
  final bool isCreator;
  final String visibilityNote;
  final List<Person> people;

  /// The photos grid, when the story links photos.
  final Widget? photos;
  final VoidCallback onToggle;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onSpeed;
  final ValueChanged<StoryMenuAction> onMenu;
  final ValueChanged<Person>? onPersonTap;

  bool get _mine => player.storyId == story.id;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final total = _mine && player.duration > Duration.zero
        ? player.duration
        : Duration(seconds: story.durationSeconds);
    final position = _mine ? player.position : Duration.zero;
    final meta = [?story.approxDateLabel, ?recordedBy].join(' · ');
    return AppScaffold(
      actions: [
        if (isCreator) ...[
          AppIconButton(
            icon: Icons.lock_outline,
            tooltip: s.storyWhoCanListen,
            onPressed: () => onMenu(StoryMenuAction.whoCanListen),
          ),
          PopupMenuButton<StoryMenuAction>(
            tooltip: s.storyMore,
            onSelected: onMenu,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: StoryMenuAction.edit,
                child: Text(s.storyEditDetails),
              ),
              PopupMenuItem(
                value: StoryMenuAction.whoCanListen,
                child: Text(s.storyWhoCanListen),
              ),
              PopupMenuItem(
                value: StoryMenuAction.delete,
                child: Text(s.storyDelete),
              ),
            ],
          ),
        ],
      ],
      body: ListView(
        padding: EdgeInsets.all(AppDimens.lg),
        children: [
          if (story.topic != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Chip(label: Text(topicLabel(s, story.topic!))),
            ),
          SizedBox(height: AppDimens.sm),
          Text(story.title, style: AppTextStyles.display),
          if (meta.isNotEmpty) ...[
            SizedBox(height: AppDimens.xs),
            Text(
              meta,
              style: AppTextStyles.caption.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          SizedBox(height: AppDimens.lg),
          AudioPlayerCard(
            subtitle: s.storyTold(narratorName),
            position: formatClock(position),
            duration: formatClock(total),
            isPlaying: _mine && player.isPlaying,
            speed: formatSpeed(player.speed),
            onToggle: onToggle,
            onSeek: (fraction) => onSeek(
              Duration(milliseconds: (total.inMilliseconds * fraction).round()),
            ),
            onSpeed: onSpeed,
            // No waveform data is stored yet: the card draws a plain track.
            waveform: const [],
          ),
          if (_mine && player.status == PlayerStatus.error) ...[
            SizedBox(height: AppDimens.sm),
            Text(
              (player.failure ?? const UnknownFailure()).message(s),
              style: AppTextStyles.caption.copyWith(color: scheme.error),
            ),
          ],
          if (story.description != null && story.description!.isNotEmpty) ...[
            SizedBox(height: AppDimens.lg),
            Text(story.description!, style: AppTextStyles.bodyLarge),
          ],
          if (people.isNotEmpty) ...[
            SizedBox(height: AppDimens.lg),
            AppSectionLabel(s.storyInThisStory),
            SizedBox(height: AppDimens.sm),
            Wrap(
              spacing: AppDimens.sm,
              runSpacing: AppDimens.sm,
              children: [
                for (final p in people)
                  ActionChip(
                    avatar: PersonAvatar(name: p.fullName, size: 24),
                    label: Text(p.fullName),
                    onPressed: onPersonTap == null
                        ? null
                        : () => onPersonTap!(p),
                  ),
              ],
            ),
          ],
          if (photos != null) ...[
            SizedBox(height: AppDimens.lg),
            AppSectionLabel(s.photos),
            SizedBox(height: AppDimens.sm),
            photos!,
          ],
          SizedBox(height: AppDimens.lg),
          Row(
            children: [
              Icon(
                Icons.people_alt_outlined,
                size: AppDimens.iconMd,
                color: scheme.onSurfaceVariant,
              ),
              SizedBox(width: AppDimens.sm),
              Expanded(
                child: Text(
                  visibilityNote,
                  style: AppTextStyles.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String formatClock(Duration d) {
    final m = d.inMinutes;
    final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  static String formatSpeed(double speed) {
    final text = speed == speed.roundToDouble()
        ? speed.toStringAsFixed(0)
        : speed.toString();
    return '$text×';
  }
}

/// Loading skeleton, "not shared with you" and error, for the story page.
class StoryStateView extends StatelessWidget {
  const StoryStateView.loading({super.key})
    : notShared = false,
      failure = null,
      onRetry = null;
  const StoryStateView.notShared({super.key})
    : notShared = true,
      failure = null,
      onRetry = null;
  const StoryStateView.error({required this.failure, this.onRetry, super.key})
    : notShared = false;

  final bool notShared;
  final AppFailure? failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return AppScaffold(
      body: notShared
          ? EmptyView(message: s.storyNotShared, icon: Icons.lock_outline)
          : failure != null
          ? ErrorView(failure: failure!, onRetry: onRetry)
          : ListView(
              padding: EdgeInsets.all(AppDimens.lg),
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                SkeletonCard(lines: 3),
                SizedBox(height: 16),
                SkeletonCard(),
              ],
            ),
    );
  }
}
