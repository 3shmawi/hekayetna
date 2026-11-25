@Tags(['golden'])
library;

import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/features/recording/presentation/continue_recording_screen.dart';
import 'package:family_stories/features/recording/presentation/continue_recording_view.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'real_font_screens_test.dart' show loadRealFonts;

/// RecordResume with the real fonts: both languages with genuinely
/// localized content (Arabic name, topic, digits and day period), light and
/// dark, and a narrow 320 px screen at 160% text. Not compared in CI.
void main() {
  setUp(loadRealFonts);

  const variants = {
    'light': (dark: false, width: 375.0, scale: 1),
    'dark': (dark: true, width: 375.0, scale: 1),
    'narrow_large': (dark: false, width: 320.0, scale: 1.6),
  };

  for (final locale in const ['en', 'ar']) {
    for (final MapEntry(key: name, value: v) in variants.entries) {
      testWidgets('record_resume · $locale · $name', (tester) async {
        tester.view
          ..physicalSize = Size(v.width, 812) * 2
          ..devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        final at = DateTime(2026, 11, 24, 20, 40);
        final now = DateTime(2026, 11, 25, 10);
        await tester.pumpWidget(
          ScreenUtilInit(
            designSize: AppDimens.designSize,
            builder: (context, _) => MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: Locale(locale),
              theme: v.dark ? AppTheme.dark : AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(v.scale.toDouble())),
                child: child!,
              ),
              home: Builder(
                builder: (context) => ContinueRecordingView(
                  items: [
                    ResumeItem(
                      id: 'a',
                      title: locale == 'ar'
                          ? 'رمضان في البيت القديم'
                          : 'Ramadan in the old house',
                      narratorName: locale == 'ar'
                          ? 'ستو فاطمة'
                          : 'Sitto Fatma',
                      stoppedAtLabel: resumeWhenLabel(
                        context.l10n,
                        locale,
                        at,
                        now,
                      ),
                      segmentMs: const [240000, 225000],
                    ),
                  ],
                  playingId: null,
                  onPlayToggle: (_) {},
                  onContinue: (_) {},
                  onSave: (_) {},
                  onDelete: (_) {},
                  onClose: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('shots/record_resume_${locale}_$name.png'),
        );
      });
    }
  }
}
