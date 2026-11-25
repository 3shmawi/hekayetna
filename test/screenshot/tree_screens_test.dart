@Tags(['golden'])
library;

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/auth/auth.dart';
import 'package:family_stories/core/router/app_redirect.dart';
import 'package:family_stories/core/router/app_router.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/family/presentation/family_tree_view.dart';
import 'package:family_stories/features/onboarding/presentation/onboarding_page.dart';
import 'package:family_stories/features/recording/data/memory_draft_store.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'real_font_screens_test.dart' show loadRealFonts;

/// Tree + onboarding visual evidence with REAL fonts: the rope-like
/// connectors, name labels, fitted layout and true RTL mirroring, in
/// light and dark. Regenerated on demand, not compared in CI.
/// Output: test/screenshot/shots/tree_*.png, onboarding_step_*.png.
void main() {
  setUp(loadRealFonts);

  Person person(String id, String name, {String? linked}) => Person(
    id: id,
    spaceId: 's',
    fullName: name,
    createdBy: 'u',
    linkedUserId: linked,
  );

  Relationship rel(
    String a,
    String b,
    RelationshipType t, [
    RelationshipStatus st = RelationshipStatus.confirmed,
  ]) => Relationship(
    id: '$a-$b-${t.name}',
    personId: a,
    relatedPersonId: b,
    type: t,
    status: st,
  );

  // Sample family, clearly demo: grandparents, their child, grandchild,
  // plus one pending invite edge (dashed).
  final persons = [
    person('giddu', 'Giddu (sample)'),
    person('sitto', 'Sitto (sample)'),
    person('mama', 'Mama (sample)'),
    person('me', 'Me (sample)', linked: 'u1'),
    person('uncle', 'Uncle (sample)'),
  ];
  final rels = [
    rel('giddu', 'sitto', RelationshipType.spouse),
    rel('mama', 'giddu', RelationshipType.parent),
    rel('mama', 'sitto', RelationshipType.parent),
    rel('me', 'mama', RelationshipType.parent),
    rel('uncle', 'mama', RelationshipType.parent, RelationshipStatus.pending),
  ];

  Widget frame({
    required Locale locale,
    required ThemeData Function() theme,
    required Widget child,
  }) => ScreenUtilInit(
    designSize: AppDimens.designSize,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      theme: theme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SafeArea(child: child)),
    ),
  );

  void fixViewport(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(375, 812) * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  // Tree, settled, AR/EN x light/dark.
  for (final locale in const ['en', 'ar']) {
    for (final mode in const ['light', 'dark']) {
      testWidgets('tree · $locale · $mode', (tester) async {
        fixViewport(tester);
        await tester.pumpWidget(
          frame(
            locale: Locale(locale),
            theme: () => mode == 'light' ? AppTheme.light : AppTheme.dark,
            child: FamilyTreeView(persons: persons, relationships: rels),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('shots/tree_${locale}_$mode.png'),
        );
      });
    }
  }

  // The entrance reveal, three frames into the 1400ms draw-in.
  for (final (i, ms) in const [(1, 300), (2, 700), (3, 1400)]) {
    testWidgets('tree anim frame $i', (tester) async {
      fixViewport(tester);
      await tester.pumpWidget(
        frame(
          locale: const Locale('en'),
          theme: () => AppTheme.light,
          child: FamilyTreeView(persons: persons, relationships: rels),
        ),
      );
      await tester.pump(Duration(milliseconds: ms));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/tree_anim_f$i.png'),
      );
    });
  }

  // Onboarding walk, every step, names typed, AR/EN light.
  for (final locale in const ['en', 'ar']) {
    testWidgets('onboarding steps · $locale', (tester) async {
      fixViewport(tester);
      await tester.pumpWidget(
        frame(
          locale: Locale(locale),
          theme: () => AppTheme.light,
          child: const ProviderScope(child: OnboardingPage()),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/onboarding_step1_$locale.png'),
      );

      await tester.tap(find.byKey(const Key('onboarding_next')));
      await tester.pumpAndSettle();
      // Latin names are valid input in the Arabic UI and must render
      // cleanly; Arabic names are covered separately below.
      await tester.enterText(find.byType(TextField), 'Me (sample)');
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/onboarding_step2_$locale.png'),
      );

      await tester.tap(find.byKey(const Key('onboarding_next')));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.first, 'Giddu (sample)');
      await tester.enterText(fields.last, 'Sitto (sample)');
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/onboarding_step3_$locale.png'),
      );

      await tester.tap(find.byKey(const Key('onboarding_next')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/onboarding_step4_$locale.png'),
      );
    });
  }

  // Arabic names in the Arabic parents step: both scripts validated.
  testWidgets('onboarding parents step · ar · arabic names', (tester) async {
    fixViewport(tester);
    await tester.pumpWidget(
      frame(
        locale: const Locale('ar'),
        theme: () => AppTheme.light,
        child: const ProviderScope(child: OnboardingPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'أنا (نموذج)');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.first, 'جدو (نموذج)');
    await tester.enterText(fields.last, 'ستو (نموذج)');
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/onboarding_step3_ar_arabic.png'),
    );
  });

  // The corrected tree inside the real app shell at small-phone size:
  // bottom nav, family tab, tree toggle, demo family. Proves the
  // in-situ clipping fix (not only the isolated widget).
  for (final locale in const ['en', 'ar']) {
    for (final mode in const ['light', 'dark']) {
      testWidgets('shell tree · $locale · $mode', (tester) async {
        tester.view
          ..physicalSize = const Size(1125, 2436)
          ..devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        demoModeSignedInOverride = true;
        Auth.user.value = null;
        addTearDown(() {
          demoModeSignedInOverride = null;
          Auth.user.value = null;
          appRouter.go('/');
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              draftStoreProvider.overrideWithValue(MemoryDraftStore()),
            ],
            child: AppUi.testWrap(
              ScreenUtilInit(
                designSize: AppDimens.designSize,
                builder: (context, _) => MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  locale: Locale(locale),
                  theme: mode == 'light' ? AppTheme.light : AppTheme.dark,
                  routerConfig: appRouter,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(locale == 'ar' ? 'العيلة' : 'Family'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(locale == 'ar' ? 'شجرة' : 'Tree'));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('shots/shell_tree_${locale}_$mode.png'),
        );
      });
    }
  }
}
