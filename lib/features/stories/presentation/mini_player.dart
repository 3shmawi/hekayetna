import 'package:family_stories/core/adaptive/adaptive.dart';
import 'package:family_stories/core/router/app_routes.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The bar shows while a story is loaded and its own page is not open.
bool shouldShowMiniPlayer({
  required String? storyId,
  required String location,
}) => storyId != null && location != AppRoutes.storyDetail(storyId);

/// A compact bar above the tab bar while a story plays and its page is not
/// open: title, play/pause and progress. Tapping it returns to the story.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    required this.title,
    required this.isPlaying,
    required this.progress,
    required this.onToggle,
    required this.onOpen,
    super.key,
  });

  final String title;
  final bool isPlaying;

  /// 0 to 1.
  final double progress;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = context.l10n;
    return Material(
      color: scheme.surface,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: scheme.outlineVariant,
            ),
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: AppDimens.lg,
                end: AppDimens.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label,
                    ),
                  ),
                  IconButton(
                    tooltip: isPlaying ? s.storyPause : s.storyPlay,
                    constraints: BoxConstraints.tightFor(
                      width: AppDimens.targetMin,
                      height: AppDimens.targetMin,
                    ),
                    onPressed: onToggle,
                    icon: Icon(
                      isPlaying
                          ? AdaptiveIcons.pause(context)
                          : AdaptiveIcons.play(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
