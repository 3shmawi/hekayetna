import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:flutter/material.dart';

/// A loading placeholder in the shape of a card (Design System StateView:
/// skeletons, never a spinner).
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({this.lines = 2, super.key});

  final int lines;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bar = scheme.outlineVariant.withValues(alpha: 0.55);
    return Container(
      padding: EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: AppDimens.avatar,
            height: AppDimens.avatar,
            decoration: BoxDecoration(shape: BoxShape.circle, color: bar),
          ),
          SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < lines; i++) ...[
                  if (i > 0) SizedBox(height: AppDimens.sm),
                  FractionallySizedBox(
                    widthFactor: i == 0 ? 0.9 : 0.6,
                    child: Container(
                      height: AppDimens.md,
                      decoration: BoxDecoration(
                        color: bar,
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
