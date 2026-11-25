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
    this.wrap = false,
    super.key,
  }) : _kind = _Kind.primary;

  const AppButton.secondary({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.busy = false,
    this.wrap = false,
    super.key,
  }) : _kind = _Kind.secondary;

  const AppButton.destructive({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.busy = false,
    this.wrap = false,
    super.key,
  }) : _kind = _Kind.destructive;

  /// Terracotta: the recording flow only.
  const AppButton.record({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.busy = false,
    this.wrap = false,
    super.key,
  }) : _kind = _Kind.record;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool busy;

  /// A long label wraps onto more lines and the button grows, instead of
  /// one line cut with an ellipsis. Only for buttons in a scrolling column:
  /// the default keeps the fixed height that Row/Expanded layouts need.
  final bool wrap;
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
    final child = ConstrainedBox(
      constraints: wrap
          ? BoxConstraints(minHeight: AppDimens.buttonHeight)
          : BoxConstraints.tightFor(height: AppDimens.buttonHeight),
      child: Center(
        widthFactor: expand ? null : 1,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: wrap ? AppDimens.sm : 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Busy: a clear spinner next to the (still readable) label.
              if (busy) ...[
                SizedBox.square(
                  dimension: AppDimens.iconMd,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(foreground),
                  ),
                ),
                SizedBox(width: AppDimens.sm),
              ] else if (icon != null) ...[
                Icon(icon, size: AppDimens.iconMd),
                SizedBox(width: AppDimens.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: wrap ? TextAlign.center : null,
                  maxLines: wrap ? null : 1,
                  overflow: wrap ? null : TextOverflow.ellipsis,
                  style: AppTextStyles.label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final style = TextButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      disabledBackgroundColor: busy
          ? background.withValues(alpha: 0.85)
          : background.withValues(alpha: 0.5),
      disabledForegroundColor: busy
          ? foreground
          : foreground.withValues(alpha: 0.6),
      padding: EdgeInsets.symmetric(horizontal: AppDimens.xl),
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
