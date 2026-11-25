import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// The app's three buttons (Design System card): primary for the one action
/// a screen exists for, secondary for the alternative, destructive for
/// delete, record for the recording flow. Height 56, radius md, label
/// **never wraps** (single line, ellipsis). `busy` shows a small progress
/// indicator and keeps the width.
class AppButton extends StatelessWidget {
  const AppButton.primary({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.busy = false,
    super.key,
  }) : _kind = _Kind.primary;

  const AppButton.secondary({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.busy = false,
    super.key,
  }) : _kind = _Kind.secondary;

  const AppButton.destructive({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.busy = false,
    super.key,
  }) : _kind = _Kind.destructive;

  /// Terracotta: the recording flow only.
  const AppButton.record({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.busy = false,
    super.key,
  }) : _kind = _Kind.record;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool busy;
  final _Kind _kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hk = context.hk;
    final (background, foreground, border) = switch (_kind) {
      _Kind.primary => (scheme.primary, scheme.onPrimary, null),
      _Kind.secondary => (
        Colors.transparent,
        scheme.primary,
        BorderSide(color: scheme.outlineVariant),
      ),
      _Kind.destructive => (scheme.errorContainer, scheme.error, null),
      _Kind.record => (hk.record, hk.onRecord, null),
    };
    // At least the standard height; a long label (Arabic, large text size,
    // narrow phone) wraps onto more lines and the button grows instead of
    // cutting the words off.
    final child = ConstrainedBox(
      constraints: BoxConstraints(minHeight: AppDimens.buttonHeight),
      child: Center(
        widthFactor: expand ? null : 1,
        child: busy
            ? SizedBox.square(
                dimension: AppDimens.iconMd,
                child: CircularProgressIndicator.adaptive(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(foreground),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: AppDimens.iconMd),
                    SizedBox(width: AppDimens.sm),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.label,
                    ),
                  ),
                ],
              ),
      ),
    );
    final style = TextButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      disabledBackgroundColor: background.withValues(alpha: 0.5),
      disabledForegroundColor: foreground.withValues(alpha: 0.6),
      padding: EdgeInsets.symmetric(
        horizontal: AppDimens.xl,
        vertical: AppDimens.sm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        side: border ?? BorderSide.none,
      ),
    );
    final button = TextButton(
      onPressed: busy ? null : onPressed,
      style: style,
      child: child,
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

enum _Kind { primary, secondary, destructive, record }
