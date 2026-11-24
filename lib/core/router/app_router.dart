import 'dart:ui' show ImageFilter;

import 'package:family_stories/core/analytics/analytics.dart';
import 'package:family_stories/core/monitoring/monitoring.dart';
import 'package:family_stories/core/router/app_redirect.dart';
import 'package:family_stories/core/router/app_routes.dart';
import 'package:family_stories/core/router/not_found_page.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/features/auth/presentation/account_page.dart';
import 'package:family_stories/features/auth/presentation/new_password_page.dart';
import 'package:family_stories/features/auth/presentation/sign_in_page.dart';
import 'package:family_stories/features/family/presentation/family_screens.dart';
import 'package:family_stories/features/onboarding/presentation/onboarding_page.dart';
import 'package:family_stories/features/recording/presentation/preview_screen.dart';
import 'package:family_stories/features/recording/presentation/record_screen.dart';
import 'package:family_stories/features/settings/presentation/settings_page.dart';
import 'package:family_stories/features/stories/presentation/story_screens.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
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
      builder: (context, state, shell) => HomeShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.stories,
              name: 'stories',
              builder: (context, state) => const StoryFeedScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  name: 'story_detail',
                  builder: (context, state) =>
                      StoryDetailScreen(storyId: state.pathParameters['id']!),
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
              builder: (context, state) => const RecordScreen(),
              routes: [
                GoRoute(
                  path: 'preview/:draftId',
                  name: 'record_preview',
                  builder: (context, state) => RecordingPreviewScreen(
                    draftId: state.pathParameters['draftId']!,
                  ),
                ),
                GoRoute(
                  path: 'new-story/:draftId',
                  name: 'record_new_story',
                  builder: (context, state) =>
                      StoryEditScreen(draftId: state.pathParameters['draftId']),
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

/// The three main tabs: stories, record, family.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return Scaffold(
      body: shell,
      // Subtle glass: the bar blurs whatever scrolls under it. Reading
      // surfaces themselves stay solid, per the approved design.
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppDimens.glassBlur,
            sigmaY: AppDimens.glassBlur,
          ),
          child: NavigationBar(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: AppDimens.glassOpacity),
            elevation: 0,
            selectedIndex: shell.currentIndex,
            onDestinationSelected: (i) =>
                shell.goBranch(i, initialLocation: i == shell.currentIndex),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.graphic_eq),
                label: s.stories,
              ),
              NavigationDestination(
                icon: const Icon(Icons.mic),
                label: s.record,
              ),
              NavigationDestination(
                icon: const Icon(Icons.people_alt_outlined),
                label: s.family,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
