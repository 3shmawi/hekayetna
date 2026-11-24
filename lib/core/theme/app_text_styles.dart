import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Every text style in the app, the Design System type scale. Colors come
/// from the theme, so these only define size, weight and line height.
/// Nothing is smaller than 15sp except [tabLabel] (12) and [countBadge]
/// (13), the two named exceptions; older family members are first-class.
abstract final class AppTextStyles {
  static TextStyle get display =>
      TextStyle(fontSize: 32.sp, fontWeight: FontWeight.w700, height: 40 / 32);
  static TextStyle get headline =>
      TextStyle(fontSize: 26.sp, fontWeight: FontWeight.w700, height: 34 / 26);
  static TextStyle get title =>
      TextStyle(fontSize: 21.sp, fontWeight: FontWeight.w600, height: 28 / 21);
  static TextStyle get bodyLarge => TextStyle(fontSize: 19.sp, height: 30 / 19);
  static TextStyle get body => TextStyle(fontSize: 17.sp, height: 26 / 17);
  static TextStyle get label =>
      TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, height: 22 / 16);
  static TextStyle get caption => TextStyle(fontSize: 15.sp, height: 21 / 15);

  /// The recording timer: big, tabular figures so it doesn't jiggle.
  static TextStyle get timer => TextStyle(
    fontSize: 44.sp,
    fontWeight: FontWeight.w600,
    height: 52 / 44,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Tab bar labels, the named 12sp exception.
  static TextStyle get tabLabel =>
      TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, height: 16 / 12);

  /// Count badges (story counts), the named 13sp exception.
  static TextStyle get countBadge =>
      TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700);
}
