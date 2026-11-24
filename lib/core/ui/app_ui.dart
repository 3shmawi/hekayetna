import 'dart:ui' show ImageFilter;

import 'package:family_stories/core/adaptive/adaptive.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:flutter/material.dart';

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
    super.key,
  });

  final String? title;
  final List<Widget> actions;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: title == null ? null : Text(title!),
        actions: actions,
      ),
      body: body,
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
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final scheme = Theme.of(context).colorScheme;
  final radius = Radius.circular(AppDimens.radiusLg);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
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
        child: ColoredBox(
          color: scheme.surface.withValues(alpha: AppDimens.sheetGlassOpacity),
          child: builder(sheetContext),
        ),
      ),
    ),
  );
}
