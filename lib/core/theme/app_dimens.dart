import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Spacing, radii and sizes, scaled to the screen with flutter_screenutil.
/// Never hard-code paddings in widgets — use these.
///
/// The scale is the Design System `tokens.json`: spacing 4/8/12/16/24/32/48,
/// radii 8/14/22/pill, sizes targetMin 48, button 56, avatar 44, play 72,
/// record 96.
abstract final class AppDimens {
  /// The size of the design (Figma) frame the UI was drawn on.
  static const designSize = Size(375, 812);

  static double get xs => 4.w;
  static double get sm => 8.w;
  static double get md => 12.w;
  static double get lg => 16.w;
  static double get xl => 24.w;
  static double get xxl => 32.w;
  static double get xxxl => 48.w;

  static double get radiusSm => 8.r;
  static double get radiusMd => 14.r;
  static double get radiusLg => 22.r;
  static double get radiusPill => 999.r;

  /// Minimum tap target (WCAG): every interactive element is at least this.
  static double get targetMin => 48.r;

  static double get buttonHeight => 56.h;
  static double get avatar => 44.r;
  static double get playButton => 72.r;
  static double get recordButton => 96.r;

  /// The record button's breathing halo.
  static double get recordHalo => 140.r;

  static double get iconMd => 24.r;

  /// Bottom sheets (`showAppSheet`): the grab handle, the blur behind
  /// glass, and the most of the screen height they take.
  static double get grabWidth => 36.w;
  static double get grabHeight => 5.h;
  static const sheetBlur = 24.0;

  /// Subtle glass (bottom bar, sheets): blur strength and surface opacity.
  static const glassBlur = 18.0;
  static const glassOpacity = 0.82;

  /// Sheets sit higher: sheet text must keep WCAG contrast over the blur.
  static const sheetGlassOpacity = 0.92;
  static const sheetMaxShare = 0.9;

  /// The widest a settings row's value gets before it wraps.
  static double get settingsValue => 150.w;
}
