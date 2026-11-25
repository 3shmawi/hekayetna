import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/auth/auth.dart';
import 'package:family_stories/core/router/app_redirect.dart';
import 'package:family_stories/core/router/app_router.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/features/auth/presentation/sign_in_page.dart';
import 'package:family_stories/features/recording/data/memory_draft_store.dart';
import 'package:family_stories/features/settings/data/settings_repository.dart';
import 'package:family_stories/features/settings/presentation/settings_controller.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/pump_app.dart';

/// Screen-level wiring tests over the demo repositories: routing, strings
/// and RTL on the real app shell. Backend behavior is covered by the RLS
/// SQL suite under supabase/tests; individual screens by their own tests.
/// The settings language switch is covered in
/// test/features/settings/presentation/settings_view_test.dart.
void main() {
  setUp(() async {
    // Real font metrics: the fallback test font is ~1em per character,
    // which mis-measures every label.
    await loadAppFonts();
    demoModeSignedInOverride = true;
    Auth.user.value = null;
  });
  tearDown(() {
    demoModeSignedInOverride = null;
    Auth.user.value = null;
    appRouter.go('/');
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view
      ..physicalSize = const Size(1125, 2436)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          draftStoreProvider.overrideWithValue(MemoryDraftStore()),
          settingsRepositoryProvider.overrideWithValue(
            SettingsRepository(prefs),
          ),
        ],
        child: AppUi.testWrap(
          ScreenUtilInit(
            designSize: AppDimens.designSize,
            builder: (context, _) => MaterialApp.router(
              locale: locale,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              routerConfig: appRouter,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('signed-in demo session lands on the stories feed', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('The first Om Ali (sample)'), findsOneWidget);
    // The demo banner must tell the truth about persistence.
    expect(find.textContaining('Demo preview'), findsOneWidget);
  });

  testWidgets('signed-out session is redirected to sign-in', (tester) async {
    demoModeSignedInOverride = false;
    await pumpApp(tester);
    expect(find.byType(SignInPage), findsOneWidget);
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.authSendLink), findsOneWidget);
  });

  testWidgets('Arabic locale renders RTL with Arabic strings', (tester) async {
    await pumpApp(tester, locale: const Locale('ar'));
    expect(find.text('الحكايات'), findsWidgets);
    final context = tester.element(find.text('الحكايات').first);
    expect(Directionality.of(context), TextDirection.rtl);
  });

  testWidgets('family tab lists people and opens a person with relationships', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();
    expect(find.text('Sitto Amina (sample)'), findsOneWidget);
    await tester.tap(find.text('Sitto Amina (sample)'));
    await tester.pumpAndSettle();
    expect(find.text('Relationships'), findsOneWidget);
    // The relationships list sits below the fold; ListView builds lazily.
    await tester.scrollUntilVisible(
      find.textContaining('Giddu Mahmoud (sample)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Giddu Mahmoud (sample)'), findsOneWidget);
  });

  testWidgets('a missing draft shows an honest error, not a fake player', (
    tester,
  ) async {
    await pumpApp(tester);
    appRouter.go('/record/preview/does-not-exist');
    await tester.pumpAndSettle();
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.errorUnknown), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
  });
}
