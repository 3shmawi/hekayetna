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
import 'package:family_stories/features/prompts/domain/prompt_logic.dart';
import 'package:family_stories/features/prompts/presentation/prompts_providers.dart';
import 'package:family_stories/features/prompts/presentation/weekly_prompt_card.dart';
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

/// Question of the week card (spec 07, AC-5, AC-6, AC-7).
void main() {
  late SharedPreferences prefs;
  late List<String> visited;
  late List<String> events;
  late PromptLibrary lib;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    visited = [];
    events = [];
    lib = PromptLibrary.fromJson(
      jsonDecode(File(kPromptLibraryAsset).readAsStringSync())
          as Map<String, dynamic>,
    );
  });

  Future<void> pump(
    WidgetTester tester, {
    required DateTime today,
    bool flag = true,
  }) async {
    tester.view
      ..physicalSize = const Size(1125, 2436)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: WeeklyPromptCard()),
        ),
        GoRoute(
          path: '/record',
          builder: (_, state) {
            visited.add(state.uri.toString());
            return const Scaffold(body: Text('record-stub'));
          },
        ),
        GoRoute(
          path: '/prompts',
          builder: (_, _) => const Scaffold(body: Text('prompts-stub')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          promptEventsProvider.overrideWithValue((event, [props]) async {
            events.add(event);
          }),
          promptLibraryProvider.overrideWith((_) => lib),
          interviewPromptsEnabledProvider.overrideWith((_) async => flag),
          promptsClockProvider.overrideWithValue(() => today),
          familyRepositoryProvider.overrideWithValue(DemoFamilyRepository()),
          storyRepositoryProvider.overrideWithValue(DemoStoryRepository()),
          settingsRepositoryProvider.overrideWithValue(
            SettingsRepository(prefs),
          ),
          savedPromptsStoreProvider.overrideWith(
            (_) async => SavedPromptsStore(prefs),
          ),
        ],
        child: ScreenUtilInit(
          designSize: AppDimens.designSize,
          builder: (context, _) => MaterialApp.router(
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

  String expectedQuestion(DateTime day) =>
      weeklyPrompt(lib.prompts, day)!.en.question;

  testWidgets('flag off renders nothing (AC-7)', (tester) async {
    await pump(tester, flag: false, today: DateTime(2026, 11, 26));
    expect(find.byKey(const ValueKey('weekly-prompt')), findsNothing);
  });

  testWidgets('shows the week question, same all week, new next week (AC-5)', (
    tester,
  ) async {
    final thursday = DateTime(2026, 11, 26);
    final sunday = DateTime(2026, 11, 29);
    final nextWeek = DateTime(2026, 12, 3);
    expect(expectedQuestion(thursday), expectedQuestion(sunday));
    expect(expectedQuestion(thursday), isNot(expectedQuestion(nextWeek)));
    await pump(tester, today: thursday);
    expect(
      find.textContaining(expectedQuestion(thursday).substring(1)),
      findsOneWidget,
    );
    // The question names who to ask, like the Main artboard.
    expect(find.textContaining('Ask '), findsWidgets);
    expect(find.text(l10nEn.promptsWeekTitle), findsOneWidget);
  });

  testWidgets('a different week shows a different question', (tester) async {
    await pump(tester, today: DateTime(2026, 12, 3));
    expect(
      find.textContaining(expectedQuestion(DateTime(2026, 12, 3)).substring(1)),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        expectedQuestion(DateTime(2026, 11, 26)).substring(1),
      ),
      findsNothing,
    );
  });

  testWidgets('dismiss hides it for the week and stays hidden', (tester) async {
    final day = DateTime(2026, 11, 26);
    await pump(tester, today: day);
    await tester.tap(find.byTooltip(l10nEn.promptsDismiss));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('weekly-prompt')), findsNothing);
    expect(prefs.getString(SavedPromptsStore.dismissedKey), weekKey(day));
    await pump(tester, today: DateTime(2026, 11, 28));
    expect(find.byKey(const ValueKey('weekly-prompt')), findsNothing);
    await pump(tester, today: DateTime(2026, 12, 3));
    expect(find.byKey(const ValueKey('weekly-prompt')), findsOneWidget);
  });

  testWidgets('Record opens Record with the narrator, topic and prompt', (
    tester,
  ) async {
    final day = DateTime(2026, 11, 26);
    await pump(tester, today: day);
    await tester.tap(find.textContaining('Record '));
    await tester.pumpAndSettle();
    final p = weeklyPrompt(lib.prompts, day)!;
    expect(visited.single, contains('topic=${p.topic}'));
    expect(visited.single, contains('prompt=${p.id}'));
    expect(prefs.getString('settings.last_narrator_id'), isNotNull);
  });

  testWidgets('More questions opens the library', (tester) async {
    await pump(tester, today: DateTime(2026, 11, 26));
    await tester.tap(find.text(l10nEn.promptsMore));
    await tester.pumpAndSettle();
    expect(find.text('prompts-stub'), findsOneWidget);
  });

  testWidgets('events: shown once, dismissed, recorded', (tester) async {
    await pump(tester, today: DateTime(2026, 11, 26));
    expect(events, ['weekly_prompt_shown']);
    await tester.tap(find.byTooltip(l10nEn.promptsDismiss));
    await tester.pumpAndSettle();
    expect(events, ['weekly_prompt_shown', 'weekly_prompt_dismissed']);
  });

  testWidgets('event: recorded when Record is tapped', (tester) async {
    await pump(tester, today: DateTime(2026, 11, 26));
    await tester.tap(find.textContaining('Record '));
    await tester.pumpAndSettle();
    expect(events, contains('weekly_prompt_recorded'));
  });

  testWidgets('flag off sends no events', (tester) async {
    await pump(tester, flag: false, today: DateTime(2026, 11, 26));
    expect(events, isEmpty);
  });
}
