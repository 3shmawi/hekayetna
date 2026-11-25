import 'dart:ui' show ImageFilter;

import 'package:family_stories/core/adaptive/adaptive.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

export 'package:family_stories/core/ui/app_button.dart';
export 'package:family_stories/core/ui/app_chip.dart';
export 'package:family_stories/core/ui/app_section_label.dart';
export 'package:family_stories/core/ui/app_tab_bar.dart';
export 'package:family_stories/core/ui/audio_player_card.dart';
export 'package:family_stories/core/ui/person_avatar.dart';
export 'package:family_stories/core/ui/record_button.dart';
export 'package:family_stories/core/ui/skeleton_card.dart';
export 'package:family_stories/core/ui/story_card.dart';
export 'package:family_stories/core/ui/visibility_picker.dart';

/// The app's UI style: adaptive (Material on Android, Cupertino touches on
/// iOS). Screens use these wrappers, never a style-specific widget, so the
/// whole app can switch style (e.g. to Liquid Glass) in this one file.
abstract final class AppUi {
  static const style = 'adaptive';

  static Future<void> initialize() async {}

  static Widget wrap(Widget app) => app;

  /// Tests render the same widgets.
  static Widget testWrap(Widget child) => child;
}

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.body,
    this.title,
    this.actions = const [],
    this.leading,
    this.bottom,
    this.background,
    super.key,
  });

  final String? title;
  final List<Widget> actions;
  final Widget? leading;
  final Widget body;

  /// A sticky area pinned above the safe area (e.g. the screen's one
  /// primary button, per the Design System).
  final Widget? bottom;

  /// Defaults to the sand scaffold background.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final background = this.background ?? context.hk.sand;
    if (context.isCupertino) {
      return CupertinoPageScaffold(
        backgroundColor: background,
        // A pushed screen with no title, leading or actions still gets the bar
        // so the back button is there (the edge swipe is not the only way).
        navigationBar:
            title == null &&
                leading == null &&
                actions.isEmpty &&
                !(ModalRoute.of(context)?.canPop ?? false)
            ? null
            : CupertinoNavigationBar(
                // Explicit, opaque colors: the default bar is a translucent
                // light grey that turned white under scrolled content in the
                // dark theme (title and back chevron became unreadable).
                backgroundColor: background,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 0.5,
                  ),
                ),
                middle: title == null
                    ? null
                    : Text(
                        title!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                leading: leading,
                trailing: actions.isEmpty
                    ? null
                    : Row(mainAxisSize: MainAxisSize.min, children: actions),
              ),
        // Cupertino's scaffold has no Material ancestor, and text fields,
        // list tiles and ink wells inside the body need one (without it the
        // sign-in screen threw "No Material widget found" on iOS).
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            child: Column(
              children: [
                Expanded(child: body),
                if (bottom != null)
                  Padding(padding: EdgeInsets.all(AppDimens.lg), child: bottom),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: title == null ? null : Text(title!),
        leading: leading,
        actions: actions,
      ),
      body: body,
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.all(AppDimens.lg),
                child: bottom,
              ),
            ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Card(child: child);
}

/// An icon button with a tooltip (also its accessibility label).
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: onPressed,
      style: context.isCupertino
          ? IconButton.styleFrom(splashFactory: NoSplash.splashFactory)
          : null,
    );
  }
}

/// Opens a bottom sheet with a grab handle; [builder]'s content scrolls
/// when it's taller than the screen allows. Drag it down or tap outside to
/// close. Returns what the sheet pops with.
///
/// [handleInside] draws the grab handle on the sheet's own surface. The
/// default leaves it to the modal, which paints it on the transparent area
/// above the sheet; that suits sheets that bring their own full-height
/// scaffold, and looks detached on a plain content sheet.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool handleInside = false,
}) {
  final scheme = Theme.of(context).colorScheme;
  final radius = Radius.circular(AppDimens.radiusLg);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: !handleInside,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * AppDimens.sheetMaxShare,
    ),
    // Subtle glass: the sheet blurs what is behind it; its own surface
    // stays readable. Solid sheets for long text stay as they are.
    builder: (sheetContext) => ClipRRect(
      borderRadius: BorderRadius.only(topLeft: radius, topRight: radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppDimens.glassBlur,
          sigmaY: AppDimens.glassBlur,
        ),
        // Material (not ColoredBox) so ListTiles inside paint their ink.
        child: Material(
          color: scheme.surface.withValues(alpha: AppDimens.sheetGlassOpacity),
          child: handleInside
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 4,
                      margin: const EdgeInsets.only(top: 10, bottom: 12),
                      decoration: BoxDecoration(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Flexible(child: builder(sheetContext)),
                  ],
                )
              : builder(sheetContext),
        ),
      ),
    ),
  );
}
