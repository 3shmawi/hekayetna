@Tags(['golden'])
library;

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/router/app_router.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/features/family/domain/family_graph.dart';
import 'package:family_stories/features/family/presentation/family_tree_page.dart';
import 'package:family_stories/features/family/presentation/family_tree_providers.dart';
import 'package:family_stories/features/recording/data/memory_draft_store.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../features/family/domain/family_fixtures.dart';
import 'real_font_screens_test.dart' show loadRealFonts;

/// The family tab inside the real app shell (tab bar and bottom safe area
/// included) with real fonts, so nothing below the tree is cropped.
/// Regenerated on demand and inspected; not compared in CI.
FamilyGraph _graph() {
  final fam = bigFamily();
  return FamilyGraph.build(
    persons: fam.persons,
    relationships: fam.rels,
    meId: 'me',
    storiesByNarrator: {
      'sitto': [600, 300, 120],
      'mama': [60],
    },
  );
}

GoRouter _router() => GoRouter(
  initialLocation: '/family',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) =>
          HomeShell(shell: shell, location: state.uri.path),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/stories', builder: (_, _) => const SizedBox()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/record', builder: (_, _) => const SizedBox()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/family',
              builder: (_, _) => const SafeArea(
                bottom: false,
                child: FamilyTreePage(
                  spaceId: 's',
                  spaceName: 'Ashmawy family',
                  onOpenPerson: _noop,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);

void _noop(String _) {}

void main() {
  setUp(loadRealFonts);
  for (final locale in const ['en', 'ar']) {
    for (final dark in const [false, true]) {
      final name = 'family_shell_${dark ? 'dark_' : ''}$locale';
      testWidgets(name, (tester) async {
        tester.view
          ..physicalSize = const Size(375, 812) * 2
          ..devicePixelRatio = 2
          ..padding = const FakeViewPadding(top: 94, bottom: 68)
          ..viewPadding = const FakeViewPadding(top: 94, bottom: 68);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              draftStoreProvider.overrideWithValue(MemoryDraftStore()),
              familyGraphProvider.overrideWith((ref, _) async => _graph()),
              familyTreeGraphEnabledProvider.overrideWith((ref) async => true),
            ],
            child: AppUi.testWrap(
              ScreenUtilInit(
                designSize: AppDimens.designSize,
                builder: (context, _) => MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  locale: Locale(locale),
                  theme: dark ? AppTheme.dark : AppTheme.light,
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
          matchesGoldenFile('shots/$name.png'),
        );
      });
    }
  }
}
