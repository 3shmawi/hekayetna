@Tags(['golden'])
library;

import 'dart:async';

import 'package:family_stories/core/auth/auth.dart';
import 'package:family_stories/core/network/app_failure.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/features/auth/presentation/sign_in_page.dart';
import 'package:family_stories/features/settings/data/settings_repository.dart';
import 'package:family_stories/features/settings/presentation/settings_controller.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_auth_service.dart';
import '../helpers/pump_app.dart';

/// The real routed [SignInPage] (language chips, brand panel, fields, error,
/// loading, keyboard) at a small phone with 160% text and at the design
/// frame, en + ar, light + dark, real fonts. Not callback-less fixtures.
class _SlowAuth extends FakeAuthService {
  @override
  Future<Result<void>> signInWithEmail({
    required String email,
    required String password,
  }) => Completer<Result<void>>().future;
}

class _Follows extends ConsumerWidget {
  const _Follows();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(settingsControllerProvider).locale;
    return Localizations.override(
      context: context,
      locale: locale,
      child: Directionality(
        textDirection: locale?.languageCode == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: const SignInPage(),
      ),
    );
  }
}

void main() {
  setUp(() async {
    await loadAppFonts();
  });
  tearDown(() => Auth.service = const UnconfiguredAuthService());

  Future<void> scene(
    WidgetTester tester, {
    required String name,
    required Size size,
    required double textScale,
    required String locale,
    required bool dark,
    String state = 'default',
  }) async {
    SharedPreferences.setMockInitialValues({'settings.locale': locale});
    final prefs = await SharedPreferences.getInstance();
    final auth = state == 'loading' ? _SlowAuth() : FakeAuthService();
    Auth.service = auth;
    Auth.user.value = null;
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            SettingsRepository(prefs),
          ),
        ],
        child: AppUi.testWrap(
          ScreenUtilInit(
            designSize: AppDimens.designSize,
            builder: (context, _) => MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: Locale(locale),
              theme: dark ? AppTheme.dark : AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                  viewInsets: state == 'keyboard'
                      ? const EdgeInsets.only(bottom: 280)
                      : EdgeInsets.zero,
                ),
                child: child!,
              ),
              home: const _Follows(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (state == 'error') {
      auth.nextFailure = const AuthFailure(
        AuthFailureReason.invalidCredentials,
      );
    }
    if (state == 'error' || state == 'loading') {
      await tester.enterText(
        find.byKey(const Key('sign_in_email')),
        'sitto@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('sign_in_password')),
        'correct-horse-x',
      );
      await tester.ensureVisible(find.byKey(const Key('sign_in_submit')));
      await tester.tap(find.byKey(const Key('sign_in_submit')));
      await tester.pump(const Duration(milliseconds: 300));
      if (state == 'error') await tester.pumpAndSettle();
    }
    if (state == 'keyboard') {
      await tester.showKeyboard(find.byKey(const Key('sign_in_password')));
      await tester.enterText(
        find.byKey(const Key('sign_in_password')),
        'hunter2hunter2',
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('evidence/auth_routed_$name.png'),
    );
  }

  const small = Size(320, 640);
  const frame = Size(375, 812);
  for (final locale in const ['en', 'ar']) {
    for (final dark in const [false, true]) {
      final t = dark ? 'dark' : 'light';
      testWidgets('small 160% $locale $t', (tester) async {
        await scene(
          tester,
          name: 'small_${locale}_$t',
          size: small,
          textScale: 1.6,
          locale: locale,
          dark: dark,
        );
      });
      testWidgets('frame $locale $t', (tester) async {
        await scene(
          tester,
          name: 'frame_${locale}_$t',
          size: frame,
          textScale: 1,
          locale: locale,
          dark: dark,
        );
      });
    }
  }
  for (final state in const ['error', 'loading', 'keyboard']) {
    testWidgets('small 160% en light $state', (tester) async {
      await scene(
        tester,
        name: 'small_en_light_$state',
        size: small,
        textScale: 1.6,
        locale: 'en',
        dark: false,
        state: state,
      );
    });
    testWidgets('frame ar dark $state', (tester) async {
      await scene(
        tester,
        name: 'frame_ar_dark_$state',
        size: frame,
        textScale: 1,
        locale: 'ar',
        dark: true,
        state: state,
      );
    });
  }
}
