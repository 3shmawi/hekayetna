@Tags(['golden'])
library;

import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/features/recording/presentation/record_page.dart';
import 'package:family_stories/features/recording/presentation/record_view.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// Recording and paused states, light/dark x en/ar (spec 04, AC-1).
/// Update with `flutter test --update-goldens test/golden/record_view_golden_test.dart`
/// and look at every PNG.
RecordView _view(String locale, RecordButtonState state) {
  final ar = locale == 'ar';
  return RecordView(
    buttonState: state,
    elapsed: const Duration(minutes: 2, seconds: 14),
    levels: [for (var i = 0; i < 20; i++) (i % 7) / 7],
    narratorName: ar ? 'ستّو أمينة' : 'Sitto Amina',
    draftSaved: true,
    canFinish: true,
    promptText: starterQuestions(lookupAppLocalizations(Locale(locale))).first,
    onDifferentQuestion: () {},
    onClose: () {},
    onToggle: () {},
    onPickNarrator: () {},
    onPickTopic: () {},
    onDone: () {},
  );
}

void main() {
  for (final state in const [
    RecordButtonState.recording,
    RecordButtonState.paused,
  ]) {
    for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
      for (final locale in const ['en', 'ar']) {
        final variant = 'record_${state.name}_${mode.name}_$locale';
        testWidgets(variant, (tester) async {
          tester.view
            ..physicalSize = const Size(375, 812) * 2
            ..devicePixelRatio = 2;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            ScreenUtilInit(
              designSize: AppDimens.designSize,
              builder: (context, _) => MaterialApp(
                debugShowCheckedModeBanner: false,
                locale: Locale(locale),
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                themeMode: mode,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: _view(locale, state),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 800));
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/record/$variant.png'),
          );
        });
      }
    }
  }
}
