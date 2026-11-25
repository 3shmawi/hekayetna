import 'package:flutter/material.dart';

/// Color for text-only actions (links, secondary labels) where the screen's
/// fill color is too dark to read as text. Set by AuthTheme in dark mode;
/// absent everywhere else, so the rest of the app keeps `colorScheme.primary`.
@immutable
class LinkColor extends ThemeExtension<LinkColor> {
  const LinkColor(this.color);

  final Color color;

  static Color of(BuildContext context) =>
      Theme.of(context).extension<LinkColor>()?.color ??
      Theme.of(context).colorScheme.primary;

  @override
  LinkColor copyWith({Color? color}) => LinkColor(color ?? this.color);

  @override
  LinkColor lerp(LinkColor? other, double t) =>
      LinkColor(Color.lerp(color, other?.color, t) ?? color);
}
