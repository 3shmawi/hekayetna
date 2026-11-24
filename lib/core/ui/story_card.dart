import 'package:family_stories/core/adaptive/adaptive.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/core/ui/person_avatar.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// One story in the feed, a person's page or search (Design System card):
/// who tells it, what it is, when it happened and how long it is. The whole
/// card opens the story; the 48px play button plays it without leaving the
/// feed. Demo content carries a gold "Sample" tag.
class StoryCard extends StatelessWidget {
  const StoryCard({
    required this.title,
    required this.narratorName,
    required this.duration,
    required this.onOpen,
    required this.onPlay,
    this.dateLabel,
    this.topicLabel,
    this.isSample = false,
    super.key,
  });

  final String title;
  final String narratorName;

  /// Approximate, on purpose ("Ramadan, late 1950s").
  final String? dateLabel;

  /// Already formatted ("2:34").
  final String duration;
  final String? topicLabel;
  final bool isSample;
  final VoidCallback onOpen;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hk = context.hk;
    final s = context.l10n;
    final meta = [narratorName, ?dateLabel, duration].join(' · ');
    return Card(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          boxShadow: AppTheme.cardShadow(scheme.brightness),
        ),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          child: Padding(
            padding: EdgeInsets.all(AppDimens.lg),
            child: Row(
              children: [
                PersonAvatar(name: narratorName),
                SizedBox(width: AppDimens.md),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.title,
                      ),
                      SizedBox(height: AppDimens.xs),
                      Text(
                        meta,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (topicLabel != null || isSample) ...[
                        SizedBox(height: AppDimens.sm),
                        Wrap(
                          spacing: AppDimens.sm,
                          runSpacing: AppDimens.xs,
                          children: [
                            if (topicLabel != null) _Tag(label: topicLabel!),
                            if (isSample)
                              _Tag(
                                label: 'Sample',
                                background: hk.goldTint,
                                foreground: hk.gold,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: AppDimens.md),
                IconButton.filledTonal(
                  onPressed: onPlay,
                  tooltip: s.storyPlay,
                  iconSize: AppDimens.iconMd,
                  constraints: BoxConstraints.tightFor(
                    width: AppDimens.targetMin,
                    height: AppDimens.targetMin,
                  ),
                  icon: Icon(AdaptiveIcons.play(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.background, this.foreground});

  final String label;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimens.sm,
        vertical: AppDimens.xs / 2,
      ),
      decoration: BoxDecoration(
        color: background ?? scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption.copyWith(
          color: foreground ?? scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
