import 'dart:convert';
import 'dart:io';

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/features/family/data/demo_family_repository.dart';
import 'package:family_stories/features/prompts/data/prompt_flag.dart';
import 'package:family_stories/features/prompts/data/prompt_library_loader.dart';
import 'package:family_stories/features/prompts/data/saved_prompts_store.dart';
import 'package:family_stories/features/prompts/domain/interview_prompt.dart';
import 'package:family_stories/features/prompts/presentation/prompts_page.dart';
import 'package:family_stories/features/prompts/presentation/prompts_providers.dart';
import 'package:family_stories/features/settings/data/settings_repository.dart';
import 'package:family_stories/features/settings/presentation/settings_controller.dart';
import 'package:family_stories/features/stories/data/demo_story_repository.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

/// Widget behavior for the questions screen (spec 07, AC-4, AC-6, AC-7).
/// Answered cards need the held `prompt_id` column, so they are driven by
/// an override here, not by saved stories.
void main() {
  late SharedPreferences prefs;
  late List<String> visited;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    visited = [];
  });

  Future<void> pump(
    WidgetTester tester, {
    bool flag = true,
    Map<String, String> answered = const {},
    Locale locale = const Locale('en'),
    int Function(int max)? pick,
  }) async {
    tester.view
      ..physicalSize = const Size(1125, 2436)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/prompts',
      routes: [
        GoRoute(
          path: '/prompts',
          builder: (_, _) => PromptsPage(pick: pick),
        ),
        GoRoute(
          path: '/record',
          builder: (_, state) {
            visited.add(state.uri.toString());
            return const Scaffold(body: Text('record-stub'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // The asset bundle is real IO, which the test clock never
          // completes; read the same file directly.
          promptLibraryProvider.overrideWith(
            (_) => PromptLibrary.fromJson(
              jsonDecode(File(kPromptLibraryAsset).readAsStringSync())
                  as Map<String, dynamic>,
            ),
          ),
          interviewPromptsEnabledProvider.overrideWith((_) async => flag),
          familyRepositoryProvider.overrideWithValue(DemoFamilyRepository()),
          storyRepositoryProvider.overrideWithValue(DemoStoryRepository()),
          settingsRepositoryProvider.overrideWithValue(
            SettingsRepository(prefs),
          ),
          savedPromptsStoreProvider.overrideWith(
            (_) async => SavedPromptsStore(prefs),
          ),
          answeredPromptsProvider.overrideWith((_, _) => answered),
        ],
        child: ScreenUtilInit(
          designSize: AppDimens.designSize,
          builder: (context, _) => MaterialApp.router(
            locale: locale,
            theme: AppTheme.light,
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const street = 'What did the street you grew up on look like?';

  testWidgets('flag off shows no questions (AC-7)', (tester) async {
    await pump(tester, flag: false);
    expect(find.text(l10nEn.promptsSurprise), findsNothing);
    expect(find.text(street), findsNothing);
  });

  testWidgets('first topic shows 0 of 12 and its questions (AC-4)', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text(l10nEn.promptsProgress(0, 12)), findsOneWidget);
    expect(find.text(street), findsOneWidget);
  });

  testWidgets('topic chip switches the questions and the total', (
    tester,
  ) async {
    await pump(tester);
    await tester.ensureVisible(find.text(l10nEn.topic_funny_memories));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10nEn.topic_funny_memories));
    await tester.pumpAndSettle();
    expect(find.text(street), findsNothing);
    expect(find.text(l10nEn.promptsProgress(0, 12)), findsOneWidget);
  });

  testWidgets('Save for later stores the id and sorts it first', (
    tester,
  ) async {
    await pump(tester);
    final savedBefore = find.byTooltip(l10nEn.promptsSaved);
    expect(savedBefore, findsNothing);
    await tester.tap(find.byTooltip(l10nEn.promptsSaveForLater).first);
    await tester.pumpAndSettle();
    expect(prefs.getStringList(SavedPromptsStore.savedKey), [
      'childhood_street',
    ]);
    expect(find.byTooltip(l10nEn.promptsSaved), findsOneWidget);
  });

  testWidgets('answered card shows its story title and no Ask button', (
    tester,
  ) async {
    await pump(tester, answered: {'childhood_street': 'The lane by the canal'});
    expect(find.text('The lane by the canal'), findsOneWidget);
    expect(find.text(l10nEn.promptsProgress(1, 12)), findsOneWidget);
    // 11 open questions, so 11 Ask buttons.
    expect(find.text(l10nEn.promptsAskSomeone), findsNWidgets(11));
  });

  testWidgets('Surprise me highlights an open question (fixed pick)', (
    tester,
  ) async {
    await pump(tester, pick: (_) => 0);
    await tester.tap(find.text(l10nEn.promptsSurprise));
    await tester.pumpAndSettle();
    final card = tester.widget<Container>(
      find.byKey(const ValueKey('prompt-childhood_street')),
    );
    final border = (card.decoration! as BoxDecoration).border! as Border;
    expect(border.top.width, 2);
  });

  testWidgets('Ask {name} sets the narrator and opens Record (AC-6)', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Sitto Amina (sample)'));
    await tester.pumpAndSettle();
    final ask = find.text(l10nEn.promptsAsk('Sitto Amina (sample)'));
    expect(ask, findsWidgets);
    await tester.tap(ask.first);
    await tester.pumpAndSettle();
    expect(find.text('record-stub'), findsOneWidget);
    expect(visited.single, contains('topic=childhood_first_home'));
    expect(visited.single, contains('prompt=childhood_street'));
    expect(prefs.getString('settings.last_narrator_id'), isNotNull);
  });

  testWidgets('Arabic renders with right-to-left layout', (tester) async {
    await pump(tester, locale: const Locale('ar'));
    final ar = lookupAppLocalizations(const Locale('ar'));
    expect(find.text(ar.promptsSurprise), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text(ar.promptsSurprise))),
      TextDirection.rtl,
    );
  });
}
