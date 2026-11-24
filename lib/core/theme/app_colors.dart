import 'package:flutter/material.dart';

/// Brand and semantic colors. Widgets read colors from
/// `Theme.of(context).colorScheme`; only use these directly for brand
/// moments or semantic states.
abstract final class AppColors {
  static const primary = Color(0xFF3F6B5C);
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFED6C02);
  static const error = Color(0xFFD32F2F);

  // Hekayetna palette (olive-tree identity, Mohamed-approved 2026-11-24) (docs/ux-design.md): warm, calm surfaces with
  // large text and touch targets - older family members are first-class.
  static const sand = Color(0xFFF6F1E7);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF25211D);
  static const inkSoft = Color(0xFF5F6B62);
  static const terracotta = Color(0xFF9C4A21);
  static const oliveTeal = Color(0xFF4F7A6E);
  static const gold = Color(0xFFC9A227);
}
