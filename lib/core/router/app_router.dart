import 'dart:async';

import 'package:family_stories/core/analytics/analytics.dart';
import 'package:family_stories/core/monitoring/monitoring.dart';
import 'package:family_stories/core/router/app_redirect.dart';
import 'package:family_stories/core/router/app_routes.dart';
import 'package:family_stories/core/router/not_found_page.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/features/auth/presentation/account_page.dart';
import 'package:family_stories/features/auth/presentation/new_password_page.dart';
import 'package:family_stories/features/auth/presentation/sign_in_page.dart';
import 'package:family_stories/features/family/presentation/family_screens.dart';
import 'package:family_stories/features/onboarding/presentation/onboarding_page.dart';
import 'package:family_stories/features/recording/presentation/continue_recording_screen.dart';
import 'package:family_stories/features/recording/presentation/record_page.dart';
import 'package:family_stories/features/recording/presentation/save_story_page.dart';
import 'package:family_stories/features/settings/presentation/settings_page.dart';
import 'package:family_stories/features/stories/player/audio_player_controller.dart';
import 'package:family_stories/features/stories/presentation/mini_player.dart';
import 'package:family_stories/features/stories/presentation/story_feed_page.dart';
import 'package:family_stories/features/stories/presentation/story_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Root navigator, used to show app-wide dialogs (e.g. the update sheet).
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// The app's router. Deep links are handled by go_router automatically.
final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.stories,
  // Root navigator only. Tabs added later (StatefulShellBranch) need their
  // own `observers: Analytics.navigatorObservers` to be tracked.
  observers: [
    ...Monitoring.navigatorObservers,
    ...Analytics.navigatorObservers,
  ],
  // App-wide redirects (core/router/app_redirect.dart): first-launch
  // onboarding, signed-in-only paths.
  refreshListenable: redirectChanges,
  redirect: (context, state) => appRedirect(state.uri),
  // Every route has a `name`: it is the screen name in analytics ($screen)
  // and monitoring. Without one a nested route reports only its own path
  // piece (e.g. ':storyId'). Names are stable; never put ids in them.
  routes: [
    GoRoute(
      path: '/',
      name: 'root',
      redirect: (context, state) => AppRoutes.stories,
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) =>
          HomeShell(shell: shell, location: state.uri.path),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.stories,
              name: 'stories',
              builder: (context, state) => const StoryFeedPage(),
              routes: [
                GoRoute(
                  path: ':id',
                  name: 'story_detail',
                  builder: (context, state) =>
                      StoryPage(storyId: state.pathParameters['id']!),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.record,
              name: 'record',
              builder: (context, state) => const RecordPage(),
              routes: [
                GoRoute(
                  path: 'continue',
                  name: 'record_continue',
                  // Over the tab bar and whatever is open (also on launch).
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => const ContinueRecordingScreen(),
                ),
                GoRoute(
                  path: 'new-story/:draftId',
                  name: 'record_new_story',
                  builder: (context, state) =>
                      SaveStoryPage(draftId: state.pathParameters['draftId']!),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.family,
              name: 'family',
              builder: (context, state) => const FamilyHomeScreen(),
              routes: [
                GoRoute(
                  path: 'people/:id',
                  name: 'person_detail',
                  builder: (context, state) =>
                      PersonDetailScreen(personId: state.pathParameters['id']!),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.settings,
      name: 'settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: AppRoutes.signIn,
      name: 'sign_in',
      builder: (context, state) => const SignInPage(),
    ),
    GoRoute(
      path: AppRoutes.account,
      name: 'account',
      builder: (context, state) => const AccountPage(),
    ),
    GoRoute(
      path: AppRoutes.newPassword,
      name: 'new_password',
      builder: (context, state) => const NewPasswordPage(),
    ),
    GoRoute(
      path: AppRoutes.welcome,
      name: 'welcome',
      builder: (context, state) => const OnboardingPage(),
    ),
  ],
  errorBuilder: (context, state) => const NotFoundPage(),
);

/// The three main tabs: stories, record, family. A mini player sits above
/// the tab bar while a story plays and its page is not the one on screen.
class HomeShell extends ConsumerWidget {
  const HomeShell({required this.shell, this.location = '', super.key});

  final StatefulNavigationShell shell;

  /// The current route path, to know whether the playing story is open.
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(audioPlayerControllerProvider);
    final storyId = player.storyId;
    final showMini = shouldShowMiniPlayer(storyId: storyId, location: location);
    return Scaffold(
      body: shell,
      // AppTabBar (design foundation): frosted bar, raised terracotta
      // record circle. Tapping the current tab pops to its root.
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showMini && storyId != null)
            MiniPlayer(
              title: player.title ?? '',
              isPlaying: player.isPlaying,
              progress: player.progress,
              onToggle: () => unawaited(
                ref.read(audioPlayerControllerProvider.notifier).toggle(),
              ),
              onOpen: () => context.go(AppRoutes.storyDetail(storyId)),
            ),
          AppTabBar(
            currentIndex: shell.currentIndex,
            onTap: (i) =>
                shell.goBranch(i, initialLocation: i == shell.currentIndex),
          ),
        ],
      ),
    );
  }
}
