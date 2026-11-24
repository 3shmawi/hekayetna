@Tags(['golden'])
library;

import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/features/auth/presentation/sign_in_view.dart';
import 'package:family_stories/features/stories/presentation/story_feed_page.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

/// Small/large phone evidence for spec 01: the feed and sign-in on a
/// 320x568 small phone and a 428x926 large phone, real fonts, en + ar.
void main() {
  setUp(() async {
    await loadAppFonts();
  });

  final scenes = <String, Widget Function()>{
    'feed': () => const ProviderScope(child: StoryFeedPage()),
    'sign_in': () => SignInView(
      onSubmit: (_, _, _) {},
      onForgotPassword: (_) {},
      onSendLink: (_) {},
    ),
  };
  final sizes = <String, Size>{
    'small': const Size(320, 568),
    'large': const Size(428, 926),
  };

  for (final s in scenes.entries) {
    for (final z in sizes.entries) {
      for (final locale in const ['en', 'ar']) {
        testWidgets('${s.key} ${z.key} $locale', (tester) async {
          tester.view
            ..physicalSize = z.value
            ..devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            AppUi.testWrap(
              ScreenUtilInit(
                designSize: AppDimens.designSize,
                builder: (context, _) => MaterialApp(
                  debugShowCheckedModeBanner: false,
                  locale: Locale(locale),
                  theme: AppTheme.light,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: s.value(),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('evidence/${s.key}_${z.key}_$locale.png'),
          );
        });
      }
    }
  }
}
