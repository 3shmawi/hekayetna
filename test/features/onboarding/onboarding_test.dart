import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/core/router/app_routes.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/features/family/data/demo_family_repository.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/family/presentation/family_screens.dart';
import 'package:family_stories/features/onboarding/data/onboarding.dart';
import 'package:family_stories/features/onboarding/presentation/onboarding_page.dart';
import 'package:family_stories/features/settings/data/settings_repository.dart';
import 'package:family_stories/features/settings/presentation/settings_controller.dart';
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

  Future<void> pumpWelcome(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
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
          path: AppRoutes.join,
          builder: (_, _) => const Scaffold(body: Text('join-stub')),
        ),
        GoRoute(
          path: AppRoutes.stories,
          builder: (_, _) => const Scaffold(body: Text('home-stub')),
        ),
      ],
    );
    addTearDown(router.dispose);
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
            builder: (context, _) => Consumer(
              builder: (context, ref, _) => MaterialApp.router(
                theme: AppTheme.light,
                locale: ref.watch(settingsControllerProvider).locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: router,
              ),
            ),
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
      expect(find.text(l10nEn.onboardingHeroTitle), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('onboarding_next')));
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
      await tester.ensureVisible(find.byKey(const Key('onboarding_next')));
      await tester.tap(find.byKey(const Key('onboarding_next')));
      await tester.pumpAndSettle();
      expect(find.text(l10nEn.onboardingYouTitle), findsOneWidget);

      await tester.tap(find.byKey(const Key('onboarding_back')));
      await tester.pumpAndSettle();
      expect(find.text(l10nEn.onboardingHeroTitle), findsOneWidget);
    });

    testWidgets('the first screen has no Skip; Skip works after it', (
      tester,
    ) async {
      await pumpWelcome(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('onboarding_skip')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('onboarding_next')));
      await tester.tap(find.byKey(const Key('onboarding_next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding_skip')));
      await tester.pumpAndSettle();
      expect(find.text('home-stub'), findsOneWidget);
      expect(Onboarding.seen.value, isTrue);
      expect(Onboarding.draft.value, isNull);
    });

    testWidgets('"I have an invite code" opens the join screen', (
      tester,
    ) async {
      await pumpWelcome(tester);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('onboarding_have_invite')),
      );
      await tester.tap(find.byKey(const Key('onboarding_have_invite')));
      await tester.pumpAndSettle();
      expect(find.text('join-stub'), findsOneWidget);
      expect(Onboarding.seen.value, isFalse);
    });

    testWidgets('the first screen switches language and keeps it', (
      tester,
    ) async {
      await pumpWelcome(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('onboarding_language')), findsOneWidget);
      expect(find.text(l10nEn.onboardingHeroTitle), findsOneWidget);

      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();
      expect(find.text(l10nEn.onboardingHeroTitle), findsNothing);
      expect(find.text(l10nAr.onboardingHeroTitle), findsOneWidget);
      expect(
        Directionality.of(
          tester.element(find.text(l10nAr.onboardingHeroTitle)),
        ),
        TextDirection.rtl,
      );
      expect(
        (await SharedPreferences.getInstance()).getString('settings.locale'),
        isNotNull,
      );

      // The choice carries into the next step.
      await tester.ensureVisible(find.byKey(const Key('onboarding_next')));
      await tester.tap(find.byKey(const Key('onboarding_next')));
      await tester.pumpAndSettle();
      expect(find.text(l10nAr.onboardingYouTitle), findsOneWidget);
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

      final space = (await repo.getMySpace().unwrap())!;
      final persons = await repo.listPersons(space.id).unwrap();
      final names = persons.map((p) => p.fullName).toList();
      expect(names, containsAll(['Mohamed', 'Ahmed', 'Fatma']));

      // Both parents hang off the new "you" person.
      final rels = await repo.listRelationships(space.id).unwrap();
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
      await tester.pumpApp(const ProviderScope(child: FamilyHomeScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('seed_tree_dismiss')));
      await tester.pumpAndSettle();
      expect(Onboarding.draft.value, isNull);
      expect(find.text(l10nEn.onboardingSeedTitle), findsNothing);
      expect(find.text('Mohamed'), findsNothing);
    });
  });
}
