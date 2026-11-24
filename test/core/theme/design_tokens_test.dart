import 'package:family_stories/core/theme/app_colors.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/core/theme/hekayetna_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// AC-1: AppTheme.light/dark use the exact token colours from the Design
/// System tokens.json (docs/designs/01-design-foundation.md).
/// AC-2: the type scale matches, nothing below 15sp except tabLabel (12)
/// and countBadge (13).
void main() {
  // Screen-scaled (.sp/.r) values need ScreenUtilInit around them, on the
  // 375x812 design frame so 1sp == 1 logical pixel.
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    binding.platformDispatcher.views.first
      ..physicalSize = const Size(1125, 2436)
      ..devicePixelRatio = 3;
    addTearDown(binding.platformDispatcher.views.first.reset);
  });
  Future<ThemeData> themeInsideScreenUtil(
    WidgetTester tester,
    ThemeData Function() build,
  ) async {
    late ThemeData theme;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (context, _) {
          theme = build();
          return const SizedBox();
        },
      ),
    );
    return theme;
  }

  group('AC-1 ColorScheme roles', () {
    final roles = <String, Color Function(ColorScheme)>{
      'primary': (s) => s.primary,
      'onPrimary': (s) => s.onPrimary,
      'primaryContainer': (s) => s.primaryContainer,
      'onPrimaryContainer': (s) => s.onPrimaryContainer,
      'secondary': (s) => s.secondary,
      'onSecondary': (s) => s.onSecondary,
      'surface': (s) => s.surface,
      'onSurface': (s) => s.onSurface,
      'onSurfaceVariant': (s) => s.onSurfaceVariant,
      'outlineVariant': (s) => s.outlineVariant,
      'surfaceContainerHigh': (s) => s.surfaceContainerHigh,
      'error': (s) => s.error,
      'errorContainer': (s) => s.errorContainer,
    };
    const lightExpected = {
      'primary': Color(0xFF3F6B5C),
      'onPrimary': Color(0xFFFFFFFF),
      'primaryContainer': Color(0xFFE3ECE6),
      'onPrimaryContainer': Color(0xFF25211D),
      'secondary': Color(0xFF2F5246),
      'onSecondary': Color(0xFFFFFFFF),
      'surface': Color(0xFFFFFDF8),
      'onSurface': Color(0xFF25211D),
      'onSurfaceVariant': Color(0xFF5A645C),
      'outlineVariant': Color(0xFFE2D9C8),
      'surfaceContainerHigh': Color(0xFFFFFFFF),
      'error': Color(0xFFB3261E),
      'errorContainer': Color(0xFFF9DEDC),
    };
    const darkExpected = {
      'primary': Color(0xFF8DB8A6),
      'onPrimary': Color(0xFF10241C),
      'primaryContainer': Color(0xFF22332C),
      'onPrimaryContainer': Color(0xFFF3ECE1),
      'secondary': Color(0xFFA9CDBD),
      'onSecondary': Color(0xFF10241C),
      'surface': Color(0xFF211E1A),
      'onSurface': Color(0xFFF3ECE1),
      'onSurfaceVariant': Color(0xFFB4BDB5),
      'outlineVariant': Color(0xFF3A342C),
      'surfaceContainerHigh': Color(0xFF2B2722),
      'error': Color(0xFFF2B8B5),
      'errorContainer': Color(0xFF3C1B19),
    };

    testWidgets('every role matches tokens, both brightnesses', (tester) async {
      final light = await themeInsideScreenUtil(tester, () => AppTheme.light);
      final dark = await themeInsideScreenUtil(tester, () => AppTheme.dark);
      for (final entry in roles.entries) {
        expect(
          entry.value(light.colorScheme),
          lightExpected[entry.key],
          reason: 'light ${entry.key}',
        );
        expect(
          entry.value(dark.colorScheme),
          darkExpected[entry.key],
          reason: 'dark ${entry.key}',
        );
      }
      expect(light.scaffoldBackgroundColor, const Color(0xFFF6F1E7));
      expect(dark.scaffoldBackgroundColor, const Color(0xFF171512));
    });

    test('card shadow exists in light theme only', () {
      expect(AppTheme.cardShadow(Brightness.light), isNotEmpty);
      expect(AppTheme.cardShadow(Brightness.dark), isEmpty);
    });
  });

  group('AC-1 HekayetnaColors extension', () {
    final fields = <String, Color Function(HekayetnaColors)>{
      'record': (h) => h.record,
      'onRecord': (h) => h.onRecord,
      'recordTint': (h) => h.recordTint,
      'gold': (h) => h.gold,
      'goldTint': (h) => h.goldTint,
      'line': (h) => h.line,
      'inkSoft': (h) => h.inkSoft,
      'sand': (h) => h.sand,
    };
    const lightExpected = {
      'record': Color(0xFF9C4A21),
      'onRecord': Color(0xFFFFFFFF),
      'recordTint': Color(0xFFF3E1D6),
      'gold': Color(0xFFC9A227),
      'goldTint': Color(0xFFF5ECD0),
      'line': Color(0xFFE2D9C8),
      'inkSoft': Color(0xFF5A645C),
      'sand': Color(0xFFF6F1E7),
    };
    const darkExpected = {
      'record': Color(0xFFE08A5C),
      'onRecord': Color(0xFF2A1408),
      'recordTint': Color(0xFF3A2418),
      'gold': Color(0xFFD9B84A),
      'goldTint': Color(0xFF332B14),
      'line': Color(0xFF3A342C),
      'inkSoft': Color(0xFFB4BDB5),
      'sand': Color(0xFF171512),
    };

    testWidgets('every field matches tokens, both brightnesses', (
      tester,
    ) async {
      final light = await themeInsideScreenUtil(tester, () => AppTheme.light);
      final dark = await themeInsideScreenUtil(tester, () => AppTheme.dark);
      final lightHk = light.extension<HekayetnaColors>()!;
      final darkHk = dark.extension<HekayetnaColors>()!;
      for (final entry in fields.entries) {
        expect(
          entry.value(lightHk),
          lightExpected[entry.key],
          reason: 'light ${entry.key}',
        );
        expect(
          entry.value(darkHk),
          darkExpected[entry.key],
          reason: 'dark ${entry.key}',
        );
      }
    });
  });

  group('AC-2 type scale', () {
    // Design System scale: name → (size, line height, weight) in sp.
    final scale = <String, (TextStyle Function(), double, double, FontWeight?)>{
      'display': (() => AppTextStyles.display, 32, 40, FontWeight.w700),
      'headline': (() => AppTextStyles.headline, 26, 34, FontWeight.w700),
      'title': (() => AppTextStyles.title, 21, 28, FontWeight.w600),
      'bodyLarge': (() => AppTextStyles.bodyLarge, 19, 30, null),
      'body': (() => AppTextStyles.body, 17, 26, null),
      'label': (() => AppTextStyles.label, 16, 22, FontWeight.w600),
      'caption': (() => AppTextStyles.caption, 15, 21, null),
      'timer': (() => AppTextStyles.timer, 44, 52, FontWeight.w600),
      'tabLabel': (() => AppTextStyles.tabLabel, 12, 16, FontWeight.w600),
      'countBadge': (() => AppTextStyles.countBadge, 13, 0, FontWeight.w700),
    };

    for (final entry in scale.entries) {
      testWidgets(entry.key, (tester) async {
        late TextStyle style;
        await tester.pumpWidget(
          ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (context, _) {
              style = entry.value.$1();
              return const SizedBox();
            },
          ),
        );
        final (_, size, lineHeight, weight) = entry.value;
        expect(style.fontSize, closeTo(size, 0.01));
        if (lineHeight > 0) {
          expect(style.height! * style.fontSize!, closeTo(lineHeight, 0.01));
        }
        if (weight != null) expect(style.fontWeight, weight);
        // Nothing below 15sp except the two named exceptions.
        if (entry.key != 'tabLabel' && entry.key != 'countBadge') {
          expect(style.fontSize, greaterThanOrEqualTo(15));
        }
      });
    }

    testWidgets('timer uses tabular figures', (tester) async {
      late TextStyle style;
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, _) {
            style = AppTextStyles.timer;
            return const SizedBox();
          },
        ),
      );
      expect(
        style.fontFeatures,
        contains(predicate<FontFeature>((f) => f.feature == 'tnum')),
      );
    });
  });

  test('AppColors aliases stay on token values', () {
    expect(AppColors.primary, AppColors.olive);
    expect(AppColors.terracotta, HekayetnaColors.light.record);
    expect(AppColors.gold, HekayetnaColors.light.gold);
    expect(AppColors.inkSoft, HekayetnaColors.light.inkSoft);
    expect(AppColors.sand, HekayetnaColors.light.sand);
  });
}
