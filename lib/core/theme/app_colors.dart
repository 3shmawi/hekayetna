import 'package:flutter/material.dart';

/// Brand and semantic colors. Widgets read colors from
/// `Theme.of(context).colorScheme` and the `HekayetnaColors` extension
/// (`context.hk`); only use these directly for brand moments or semantic
/// states.
///
/// Values are the Design System `tokens.json` table (light values below;
/// dark values live in `HekayetnaColors.dark` and `AppTheme.dark`).
abstract final class AppColors {
  // Light theme tokens (docs/designs/01-design-foundation.md → Tokens).
  static const sand = Color(0xFFF6FBF4);
  static const surface = Color(0xFFFFFFFF);

  /// Filled form fields (Stitch surface-container).
  static const field = Color(0xFFEBEFE8);
  static const surfaceRaised = Color(0xFFFFFFFF);
  static const line = Color(0xFFDFE4DD);
  static const ink = Color(0xFF181D19);
  static const inkSoft = Color(0xFF4F564F);
  static const olive = Color(0xFF243828);
  static const oliveDeep = Color(0xFF0F2214);
  static const onOlive = Color(0xFFFFFFFF);
  static const oliveTint = Color(0xFFE0EBDF);

  /// WhatsApp's brand green, the one allowed brand colour (the Send on
  /// WhatsApp button). The darker brand tone is used so the white label
  /// passes contrast; the bright #25D366 does not with white text.
  static const whatsapp = Color(0xFF075E54);
  static const terracotta = Color(0xFF9C4A21);
  static const onTerracotta = Color(0xFFFFFFFF);
  static const terracottaTint = Color(0xFFF3E1D6);
  static const gold = Color(0xFFC9A227);
  static const goldTint = Color(0xFFF5ECD0);
  static const error = Color(0xFFB3261E);
  static const errorTint = Color(0xFFF9DEDC);

  // Compatibility aliases for screens specs 03-05 rebuild later.
  static const Color primary = olive;
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFED6C02);
  static const Color oliveTeal = Color(0xFF4F7A6E);
}
