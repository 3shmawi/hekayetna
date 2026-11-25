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
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.inkSoft,
    outlineVariant: AppColors.line,
    surfaceContainerHigh: AppColors.field,
    error: AppColors.error,
    errorContainer: AppColors.errorTint,
  );

  static const _darkScheme = ColorScheme.dark(
    primary: Color(0xFFB5CDB6),
    onPrimary: Color(0xFF0F2214),
    primaryContainer: Color(0xFF27372C),
    onPrimaryContainer: Color(0xFFF3F7F2),
    secondary: Color(0xFFB5CDB6),
    onSecondary: Color(0xFF0F2214),
    surface: Color(0xFF1A251E),
    onSurface: Color(0xFFF3F7F2),
    onSurfaceVariant: Color(0xFF9EACA1),
    outlineVariant: Color(0xFF27372C),
    surfaceContainerHigh: Color(0xFF1F2D24),
    error: Color(0xFFF2B8B5),
    errorContainer: Color(0xFF3C1B19),
  );

  /// Design-system `shadow-record` (0 10px 30px, terracotta at 35%): under
  /// the record button only. The token is single-valued, so both themes use
  /// it as specified.
  static const List<BoxShadow> recordShadow = [
    BoxShadow(color: Color(0x599C4A21), blurRadius: 30, offset: Offset(0, 10)),
  ];

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

  /// Filled, bordered fields with one set of states, used by every form.
  static InputDecorationTheme _inputTheme(
    ColorScheme scheme,
    HekayetnaColors hk,
    BorderRadius radius,
  ) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      contentPadding: EdgeInsetsDirectional.fromSTEB(
        AppDimens.lg,
        AppDimens.lg,
        AppDimens.lg,
        AppDimens.lg,
      ),
      border: border(Colors.transparent),
      enabledBorder: border(Colors.transparent),
      focusedBorder: border(scheme.primary, 2),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, 2),
      disabledBorder: border(Colors.transparent),
      labelStyle: AppTextStyles.body.copyWith(color: hk.inkSoft),
      floatingLabelStyle: AppTextStyles.caption.copyWith(color: scheme.primary),
      hintStyle: AppTextStyles.body.copyWith(color: hk.inkSoft),
      helperStyle: AppTextStyles.caption.copyWith(color: hk.inkSoft),
      errorStyle: AppTextStyles.caption.copyWith(color: scheme.error),
      errorMaxLines: 3,
    );
  }

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
        headlineLarge: AppTextStyles.display,
        headlineMedium: AppTextStyles.headline,
        headlineSmall: AppTextStyles.headline,
        titleLarge: AppTextStyles.title,
        titleMedium: AppTextStyles.title,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.body,
        labelLarge: AppTextStyles.label,
        bodySmall: AppTextStyles.caption,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: hk.sand,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: AppTextStyles.title.copyWith(color: scheme.onSurface),
      ),
      inputDecorationTheme: _inputTheme(scheme, hk, radius),
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
