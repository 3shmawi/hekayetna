@Tags(['golden'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/auth/auth.dart';
import 'package:family_stories/core/router/app_redirect.dart';
import 'package:family_stories/core/router/app_router.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/features/recording/data/memory_draft_store.dart';
import 'package:family_stories/features/settings/data/settings_repository.dart';
import 'package:family_stories/features/settings/presentation/settings_controller.dart';
import 'package:family_stories/features/stories/data/story_repository.dart';
import 'package:family_stories/features/stories/presentation/story_feed_page.dart';
import 'package:family_stories/features/stories/presentation/story_page.dart';
import 'package:family_stories/features/stories/presentation/story_providers.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'real_font_screens_test.dart' show loadRealFonts;

/// The story page pushed from the feed through the app's real `appRouter`
/// (the tab shell, the `stories/:id` route, the real redirects in demo mode)
/// on in-memory demo data. It is not a device test: no real backend, no
/// VoiceOver/TalkBack, and the person chips on the story are the demo ones.
///
/// Why: on iOS a screen with no title, leading or actions got no navigation
/// bar, so a story someone else recorded had no back button.

/// Cupertino icons from the package, so iOS shots show real glyphs.
Future<void> _loadCupertinoIcons() async {
  final config =
      jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
          as Map<String, dynamic>;
  final pkg = (config['packages'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((p) => p['name'] == 'cupertino_icons');
  final root = Uri.parse(
    '${File('.dart_tool/package_config.json').absolute.uri.resolve(pkg['rootUri'] as String)}/',
  );
  final font = File.fromUri(root.resolve('assets/CupertinoIcons.ttf'));
  final loader = FontLoader('packages/cupertino_icons/CupertinoIcons')
    ..addFont(Future.value(ByteData.view(font.readAsBytesSync().buffer)));
  await loader.load();
}

String _firstId(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(StoryFeedPage)),
  );
  return container.read(storyFeedProvider(const StoryFilter())).value!.first.id;
}

Future<void> _pump(
  WidgetTester tester, {
  required TargetPlatform platform,
  String? userId,
}) async {
  tester.view
    ..physicalSize = const Size(375, 812) * 2
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  appRouter.go('/stories');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        draftStoreProvider.overrideWithValue(MemoryDraftStore()),
        settingsRepositoryProvider.overrideWithValue(SettingsRepository(prefs)),
        if (userId != null) currentUserIdProvider.overrideWithValue(userId),
      ],
      child: AppUi.testWrap(
        ScreenUtilInit(
          designSize: AppDimens.designSize,
          builder: (context, _) => MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light.copyWith(platform: platform),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: appRouter,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(StoryFeedPage), findsOneWidget);
  unawaited(appRouter.push('/stories/${_firstId(tester)}'));
  await tester.pumpAndSettle();
  expect(find.byType(StoryPage), findsOneWidget);
}

void main() {
  setUp(() async {
    await loadRealFonts();
    await _loadCupertinoIcons();
    demoModeSignedInOverride = true;
    Auth.user.value = null;
  });
  tearDown(() {
    demoModeSignedInOverride = null;
    Auth.user.value = null;
    appRouter.go('/');
  });

  testWidgets('Android: the back arrow returns to the feed', (tester) async {
    await _pump(tester, platform: TargetPlatform.android);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/story_pushed_android_story.png'),
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(StoryPage), findsNothing);
    expect(find.byType(StoryFeedPage), findsOneWidget);
  });

  testWidgets('iOS, story you recorded: the back button returns to the feed', (
    tester,
  ) async {
    await _pump(tester, platform: TargetPlatform.iOS);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/story_pushed_iOS_story.png'),
    );
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await tester.pumpAndSettle();
    expect(find.byType(StoryFeedPage), findsOneWidget);
  });

  testWidgets(
    'iOS, story someone else recorded: back button present and works',
    (tester) async {
      await _pump(tester, platform: TargetPlatform.iOS, userId: 'someone-else');
      expect(find.byType(CupertinoNavigationBarBackButton), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/story_pushed_iOS_not_creator.png'),
      );
      await tester.tap(find.byType(CupertinoNavigationBarBackButton));
      await tester.pumpAndSettle();
      expect(find.byType(StoryPage), findsNothing);
      expect(find.byType(StoryFeedPage), findsOneWidget);
    },
  );
}
