@Tags(['golden'])
library;

import 'dart:async';

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/core/update/app_version.dart';
import 'package:family_stories/core/update/update_dialog.dart';
import 'package:family_stories/core/update/update_info.dart';
import 'package:family_stories/features/auth/presentation/sign_in_view.dart';
import 'package:family_stories/features/onboarding/presentation/onboarding_page.dart';
import 'package:family_stories/features/recording/data/memory_draft_store.dart';
import 'package:family_stories/features/settings/data/app_settings.dart';
import 'package:family_stories/features/settings/presentation/settings_view.dart';
import 'package:family_stories/features/stories/presentation/story_screens.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Every main screen in light and dark, left-to-right (English) and
/// right-to-left (Arabic), on the 375×812 design frame. A change that
/// moves, recolours or mirrors something shows up as a failing golden:
/// look at `test/golden/failures/`, and if the change is intended run
///
///   flutter test --update-goldens test/golden
///
/// and commit the new PNGs in `test/golden/goldens/`. Add a screen to
/// [screens] when you add one to the app.
final Map<String, Widget Function()> screens = {
  'home': () => const _DemoScope(child: StoryFeedScreen()),
  'settings': () => SettingsView(
    settings: const AppSettings(),
    onLocaleChanged: (_) {},
    onThemeModeChanged: (_) {},
    onOpenPrivacy: () {},
    onOpenTerms: () {},
    onOpenLicenses: () {},
  ),
  'update_optional': () => _SheetHost(info: _update(UpdateType.optional)),
  'update_force': () => ForcedUpdatePage(info: _update(UpdateType.force)),
  'sign_in': () => SignInView(
    onSubmit: (_, _, _) {},
    onForgotPassword: (_) {},
    onSendLink: (_) {},
  ),
  'onboarding': () => const OnboardingPage(),
};

UpdateInfo _update(UpdateType type) => UpdateInfo(
  type: type,
  current: const AppVersion(1, 0, 0),
  config: const VersionConfig(
    latest: AppVersion(1, 1, 0),
    minSupported: AppVersion(1, 0, 0),
    storeUrl: 'https://example.com',
    changelogEn: '- Faster search\n- Dark mode fixes',
    changelogAr: '- بحث أسرع\n- إصلاحات الوضع الداكن',
  ),
);

/// Demo repositories and an in-memory draft store for standalone renders.
class _DemoScope extends StatelessWidget {
  const _DemoScope({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [draftStoreProvider.overrideWithValue(MemoryDraftStore())],
    child: child,
  );
}

/// Opens the optional-update sheet over the home screen, as the app does.
class _SheetHost extends StatefulWidget {
  const _SheetHost({required this.info});

  final UpdateInfo info;

  @override
  State<_SheetHost> createState() => _SheetHostState();
}

class _SheetHostState extends State<_SheetHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(showUpdateDialog(context, widget.info)),
    );
  }

  @override
  Widget build(BuildContext context) =>
      const _DemoScope(child: StoryFeedScreen());
}

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'app',
      packageName: 'com.example.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  for (final MapEntry(key: name, value: build) in screens.entries) {
    for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
      for (final locale in const ['en', 'ar']) {
        final variant = '${name}_${mode.name}_$locale';
        testWidgets(variant, (tester) async {
          tester.view
            ..physicalSize = const Size(375, 812) * 2
            ..devicePixelRatio = 2;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            AppUi.testWrap(
              ScreenUtilInit(
                designSize: AppDimens.designSize,
                builder: (context, _) => MaterialApp(
                  debugShowCheckedModeBanner: false,
                  locale: Locale(locale),
                  theme: AppTheme.light,
                  darkTheme: AppTheme.dark,
                  themeMode: mode,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: build(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/$variant.png'),
          );
        });
      }
    }
  }
}
