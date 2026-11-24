import 'package:family_stories/core/theme/app_colors.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_fonts.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/core/theme/hekayetna_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Light and dark themes built from the Design System tokens: the
/// `ColorScheme` is set explicitly (never `fromSeed`) so it matches
/// `tokens.json` exactly, and the extra brand colors ride along in
/// `HekayetnaColors`. Must be read inside `ScreenUtilInit` (sizes are
/// screen-scaled).
abstract final class AppTheme {
  static ThemeData get light => _build(_lightScheme, HekayetnaColors.light);
  static ThemeData get dark => _build(_darkScheme, HekayetnaColors.dark);

  static const _lightScheme = ColorScheme.light(
    primary: AppColors.olive,
    primaryContainer: AppColors.oliveTint,
    onPrimaryContainer: AppColors.ink,
    secondary: AppColors.oliveDeep,
    onSecondary: AppColors.onOlive,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.inkSoft,
    outlineVariant: AppColors.line,
    surfaceContainerHigh: AppColors.surfaceRaised,
    error: AppColors.error,
    errorContainer: AppColors.errorTint,
  );

  static const _darkScheme = ColorScheme.dark(
    primary: Color(0xFF8DB8A6),
    onPrimary: Color(0xFF10241C),
    primaryContainer: Color(0xFF22332C),
    onPrimaryContainer: Color(0xFFF3ECE1),
    secondary: Color(0xFFA9CDBD),
    onSecondary: Color(0xFF10241C),
    surface: Color(0xFF211E1A),
    onSurface: Color(0xFFF3ECE1),
    onSurfaceVariant: Color(0xFFB4BDB5),
    outlineVariant: Color(0xFF3A342C),
    surfaceContainerHigh: Color(0xFF2B2722),
    error: Color(0xFFF2B8B5),
    errorContainer: Color(0xFF3C1B19),
  );

  /// Cards carry a shadow in the light theme only; the dark theme steps
  /// surfaces instead.
  static List<BoxShadow> cardShadow(Brightness brightness) =>
      brightness == Brightness.light
      ? const [
          BoxShadow(
            color: Color(0x1425211D),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ]
      : const [];

  static ThemeData _build(ColorScheme scheme, HekayetnaColors hk) {
    final radius = BorderRadius.circular(AppDimens.radiusMd);
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: hk.sand,
      fontFamily: AppFonts.latin,
      fontFamilyFallback: const [AppFonts.arabic],
      extensions: [hk],
      textTheme: TextTheme(
        displaySmall: AppTextStyles.display,
        headlineSmall: AppTextStyles.headline,
        titleMedium: AppTextStyles.title,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.body,
        labelLarge: AppTextStyles.label,
        bodySmall: AppTextStyles.caption,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size.fromHeight(AppDimens.buttonHeight),
          shape: RoundedRectangleBorder(borderRadius: radius),
          // A button textStyle replaces the ambient DefaultTextStyle, so
          // the fonts must be restated here: without this Arabic button
          // labels fall back to the system font instead of Cairo.
          textStyle: AppTextStyles.label.copyWith(
            fontFamily: AppFonts.latin,
            fontFamilyFallback: const [AppFonts.arabic],
          ),
        ),
      ),
      cupertinoOverrideTheme: CupertinoThemeData(
        primaryColor: scheme.primary,
        brightness: scheme.brightness,
      ),
    );
  }
}

/// The Hekayetna brand colors for this context's brightness.
extension HekayetnaTheme on BuildContext {
  HekayetnaColors get hk => Theme.of(this).extension<HekayetnaColors>()!;
}
