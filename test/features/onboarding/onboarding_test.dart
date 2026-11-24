import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/router/app_routes.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/features/family/data/demo_family_repository.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/family/presentation/family_screens.dart';
import 'package:family_stories/features/onboarding/data/onboarding.dart';
import 'package:family_stories/features/onboarding/presentation/onboarding_page.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

void main() {
  Future<void> loadPrefs([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    Onboarding.load(await SharedPreferences.getInstance());
  }

  Future<void> pumpWelcome(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(1125, 2436)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: AppRoutes.welcome,
      routes: [
        GoRoute(
          path: AppRoutes.welcome,
          builder: (_, _) => const OnboardingPage(),
        ),
        GoRoute(
          path: AppRoutes.stories,
          builder: (_, _) => const Scaffold(body: Text('home-stub')),
        ),
      ],
    );
    addTearDown(router.dispose);
    return tester.pumpWidget(
      AppUi.testWrap(
        ScreenUtilInit(
          designSize: AppDimens.designSize,
          builder: (context, _) => MaterialApp.router(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      ),
    );
  }

  group('onboardingRedirect', () {
    test('sends a new install from home to the welcome screens', () {
      expect(
        onboardingRedirect(Uri.parse(AppRoutes.home), seen: false),
        AppRoutes.welcome,
      );
    });

    test('lets deep links through, and stops once seen', () {
      expect(
        onboardingRedirect(Uri.parse(AppRoutes.settings), seen: false),
        isNull,
      );
      expect(onboardingRedirect(Uri.parse(AppRoutes.home), seen: true), isNull);
    });
  });

  test('completing is saved on the device', () async {
    await loadPrefs();
    expect(Onboarding.seen.value, isFalse);

    await Onboarding.complete();
    final prefs = await SharedPreferences.getInstance();
    Onboarding.load(prefs);
    expect(Onboarding.seen.value, isTrue);
  });

  test('the draft round-trips through the device store', () async {
    await loadPrefs();
    expect(Onboarding.draft.value, isNull);

    await Onboarding.saveDraft(
      const OnboardingDraft(name: 'Mohamed', father: 'Ahmed'),
    );
    final prefs = await SharedPreferences.getInstance();
    Onboarding.load(prefs);
    expect(Onboarding.draft.value?.names, ['Mohamed', 'Ahmed']);

    await Onboarding.clearDraft();
    expect(Onboarding.draft.value, isNull);
  });

  test('an all-empty draft is dropped instead of saved', () async {
    await loadPrefs();
    await Onboarding.saveDraft(const OnboardingDraft());
    expect(Onboarding.draft.value, isNull);
  });

  group(OnboardingPage, () {
    setUp(() async {
      await loadPrefs();
    });

    testWidgets('walking through the steps saves the entered names', (
      tester,
    ) async {
      await pumpWelcome(tester);
      await tester.pumpAndSettle();
      expect(find.text(l10nEn.onboardingWelcomeTitle), findsOneWidget);

      await tester.tap(find.byKey(const Key('onboarding_next')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('onboarding_name')),
        'Mohamed',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('onboarding_next')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('onboarding_father')),
        'Ahmed',
      );
      await tester.enterText(
        find.byKey(const Key('onboarding_mother')),
        'Fatma',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('onboarding_next')));
      await tester.pumpAndSettle();
      expect(find.text(l10nEn.onboardingReadyTitle), findsOneWidget);

      await tester.tap(find.byKey(const Key('onboarding_next')));
      await tester.pumpAndSettle();
      expect(find.text('home-stub'), findsOneWidget);
      expect(Onboarding.seen.value, isTrue);
      expect(Onboarding.draft.value?.names, ['Mohamed', 'Ahmed', 'Fatma']);
    });

    testWidgets('back returns to the previous step', (tester) async {
      await pumpWelcome(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding_next')));
      await tester.pumpAndSettle();
      expect(find.text(l10nEn.onboardingYouTitle), findsOneWidget);

      await tester.tap(find.byKey(const Key('onboarding_back')));
      await tester.pumpAndSettle();
      expect(find.text(l10nEn.onboardingWelcomeTitle), findsOneWidget);
    });

    testWidgets('Skip finishes at once without a draft', (tester) async {
      await pumpWelcome(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding_skip')));
      await tester.pumpAndSettle();
      expect(find.text('home-stub'), findsOneWidget);
      expect(Onboarding.seen.value, isTrue);
      expect(Onboarding.draft.value, isNull);
    });

    testWidgets('meets accessibility guidelines', (tester) async {
      await pumpWelcome(tester);
      await tester.expectAccessible();
    });
  });

  group('seed tree card', () {
    setUp(() async {
      await loadPrefs();
    });

    testWidgets('offers the draft names and adds them to the tree', (
      tester,
    ) async {
      final repo = DemoFamilyRepository();
      Onboarding.draft.value = const OnboardingDraft(
        name: 'Mohamed',
        father: 'Ahmed',
        mother: 'Fatma',
      );
      addTearDown(() => Onboarding.draft.value = null);
      await tester.pumpApp(
        ProviderScope(
          overrides: [familyRepositoryProvider.overrideWithValue(repo)],
          child: const FamilyHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10nEn.onboardingSeedTitle), findsOneWidget);
      expect(find.textContaining('Mohamed, Ahmed, Fatma'), findsOneWidget);

      await tester.tap(find.byKey(const Key('seed_tree_add')));
      await tester.pumpAndSettle();
      expect(Onboarding.draft.value, isNull);
      expect(find.text(l10nEn.onboardingSeedTitle), findsNothing);

      final space = (await repo.getMySpace())!;
      final persons = await repo.listPersons(space.id);
      final names = persons.map((p) => p.fullName).toList();
      expect(names, containsAll(['Mohamed', 'Ahmed', 'Fatma']));

      // Both parents hang off the new "you" person.
      final rels = await repo.listRelationships(space.id);
      final you = persons.firstWhere((p) => p.fullName == 'Mohamed');
      final parents = rels
          .where(
            (r) => r.personId == you.id && r.type == RelationshipType.parent,
          )
          .map((r) => r.relatedPersonId)
          .toSet();
      final parentNames = persons
          .where((p) => parents.contains(p.id))
          .map((p) => p.fullName)
          .toSet();
      expect(parentNames, {'Ahmed', 'Fatma'});
    });

    testWidgets('dismissing drops the draft without adding anyone', (
      tester,
    ) async {
      Onboarding.draft.value = const OnboardingDraft(name: 'Mohamed');
      addTearDown(() => Onboarding.draft.value = null);
      await tester.pumpApp(
        const ProviderScope(child: FamilyHomeScreen()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('seed_tree_dismiss')));
      await tester.pumpAndSettle();
      expect(Onboarding.draft.value, isNull);
      expect(find.text(l10nEn.onboardingSeedTitle), findsNothing);
      expect(find.text('Mohamed'), findsNothing);
    });
  });
}
