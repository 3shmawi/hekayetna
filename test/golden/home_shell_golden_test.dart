@Tags(['golden'])
library;

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/router/app_router.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/features/recording/data/memory_draft_store.dart';
import 'package:family_stories/features/stories/player/audio_player_controller.dart';
import 'package:family_stories/features/stories/presentation/story_feed_page.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/pump_app.dart';

/// A story is playing, so the mini player shows above the tab bar.
class _Playing extends AudioPlayerController {
  @override
  PlayerState build() => const PlayerState(
    storyId: 's1',
    title: 'The first Om Ali',
    status: PlayerStatus.playing,
    duration: Duration(seconds: 154),
    position: Duration(seconds: 62),
  );
}

GoRouter _router() => GoRouter(
  initialLocation: '/stories',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) =>
          HomeShell(shell: shell, location: state.uri.path),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/stories', builder: (_, _) => const StoryFeedPage()),
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

void main() {
  setUp(loadAppFonts);

  for (final locale in const ['en', 'ar']) {
    for (final playing in const [false, true]) {
      final variant = 'home_shell_${playing ? 'mini_' : ''}light_$locale';
      testWidgets(variant, (tester) async {
        tester.view
          ..physicalSize = const Size(375, 812) * 2
          ..devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              draftStoreProvider.overrideWithValue(MemoryDraftStore()),
              if (playing)
                audioPlayerControllerProvider.overrideWith(_Playing.new),
            ],
            child: AppUi.testWrap(
              ScreenUtilInit(
                designSize: AppDimens.designSize,
                builder: (context, _) => MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  locale: Locale(locale),
                  theme: AppTheme.light,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  routerConfig: _router(),
                ),
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
