@Tags(['golden'])
library;

import 'dart:async';

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/router/app_router.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/features/recording/data/memory_draft_store.dart';
import 'package:family_stories/features/stories/data/story_repository.dart';
import 'package:family_stories/features/stories/presentation/story_feed_page.dart';
import 'package:family_stories/features/stories/presentation/story_page.dart';
import 'package:family_stories/features/stories/presentation/story_providers.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'real_font_screens_test.dart' show loadRealFonts;

GoRouter _router() => GoRouter(
  initialLocation: '/stories',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) =>
          HomeShell(shell: shell, location: state.uri.path),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/stories',
              builder: (_, _) => const StoryFeedPage(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, s) =>
                      StoryPage(storyId: s.pathParameters['id']!),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/record', builder: (_, _) => const SizedBox()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/family', builder: (_, _) => const SizedBox()),
          ],
        ),
      ],
    ),
  ],
);

String _firstId(WidgetTester tester) {
  final ctx = tester.element(find.byType(StoryFeedPage));
  final container = ProviderScope.containerOf(ctx);
  final feed = container.read(storyFeedProvider(const StoryFilter())).value;
  return feed!.first.id;
}

void main() {
  setUp(loadRealFonts);
  for (final platform in const [TargetPlatform.android, TargetPlatform.iOS]) {
    final name = 'story_pushed_${platform.name}';
    testWidgets(name, (tester) async {
      tester.view
        ..physicalSize = const Size(375, 812) * 2
        ..devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final router = _router();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [draftStoreProvider.overrideWithValue(MemoryDraftStore())],
          child: AppUi.testWrap(
            ScreenUtilInit(
              designSize: AppDimens.designSize,
              builder: (context, _) => MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light.copyWith(platform: platform),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: router,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/${name}_feed.png'),
      );
      // Open the first story the way a tap does: context.push.
      final first = find.byType(StoryFeedPage);
      expect(first, findsOneWidget);
      unawaited(tester.element(first).push('/stories/${_firstId(tester)}'));
      await tester.pumpAndSettle();
      expect(find.byType(StoryPage), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/${name}_story.png'),
      );
      // A way back exists on both platforms (Material arrow or the iOS bar).
      expect(
        find.byTooltip('Back').evaluate().length +
            find.byType(CupertinoNavigationBarBackButton).evaluate().length,
        1,
      );
    });
  }

  // A story someone else recorded has no menu actions. AppScaffold used to
  // drop the iOS navigation bar when there was no title, leading or action,
  // leaving the edge swipe as the only way back.
  testWidgets('iOS: a story someone else recorded still has a back button', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(375, 812) * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final router = _router();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          draftStoreProvider.overrideWithValue(MemoryDraftStore()),
          currentUserIdProvider.overrideWithValue('someone-else'),
        ],
        child: ScreenUtilInit(
          designSize: AppDimens.designSize,
          builder: (context, _) => MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light.copyWith(platform: TargetPlatform.iOS),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final ctx = tester.element(find.byType(StoryFeedPage));
    // ignore: unawaited_futures, cascade_invocations, completes on pop.
    ctx.push('/stories/${_firstId(tester)}');
    await tester.pumpAndSettle();
    expect(find.byType(StoryPage), findsOneWidget);
    expect(find.byType(CupertinoNavigationBarBackButton), findsOneWidget);
  });
}
