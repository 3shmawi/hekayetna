import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// A filter/topic pill (Design System card): `line` border on `surface`,
/// selected is an `olive` border on `olive-tint`. Minimum height 48 so
/// elders can tap it.
class AppChip extends StatelessWidget {
  const AppChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    this.trailing,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          child: Container(
            constraints: BoxConstraints(minHeight: AppDimens.targetMin),
            padding: EdgeInsets.symmetric(
              horizontal: AppDimens.lg,
              vertical: AppDimens.xs,
            ),
            decoration: BoxDecoration(
              color: selected ? scheme.primaryContainer : scheme.surface,
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  leading!,
                  SizedBox(width: AppDimens.sm),
                ],
                Flexible(
                  child: ExcludeSemantics(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label.copyWith(
                        color: selected
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  SizedBox(width: AppDimens.sm),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
