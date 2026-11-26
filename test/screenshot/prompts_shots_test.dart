@Tags(['golden'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/core/ui/record_button.dart';
import 'package:family_stories/features/family/data/demo_family_repository.dart';
import 'package:family_stories/features/prompts/data/prompt_flag.dart';
import 'package:family_stories/features/prompts/data/prompt_library_loader.dart';
import 'package:family_stories/features/prompts/data/saved_prompts_store.dart';
import 'package:family_stories/features/prompts/domain/interview_prompt.dart';
import 'package:family_stories/features/prompts/presentation/prompts_page.dart';
import 'package:family_stories/features/prompts/presentation/prompts_providers.dart';
import 'package:family_stories/features/prompts/presentation/weekly_prompt_card.dart';
import 'package:family_stories/features/recording/presentation/record_view.dart';
import 'package:family_stories/features/settings/data/settings_repository.dart';
import 'package:family_stories/features/settings/presentation/settings_controller.dart';
import 'package:family_stories/features/stories/data/demo_story_repository.dart';
import 'package:family_stories/features/stories/presentation/story_feed_page.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'real_font_screens_test.dart' show loadRealFonts;

/// Questions to ask screen and the question-of-the-week card with the real
/// fonts, light/dark x en/ar (spec 07). One card is shown as answered and one as saved,
/// from overrides. Update with `flutter test --update-goldens
/// test/screenshot/prompts_shots_test.dart` and look at every PNG.
void main() {
  setUp(loadRealFonts);

  for (final screen in const [
    'page',
    'week',
    'record',
    'recordlarge',
    'recordlargebottom',
    'feed',
  ]) {
    for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
      for (final locale in const ['en', 'ar']) {
        final variant = 'prompts_${screen}_${mode.name}_$locale';
        testWidgets(variant, (tester) async {
          SharedPreferences.setMockInitialValues({
            SavedPromptsStore.savedKey: ['childhood_games'],
          });
          final prefs = await SharedPreferences.getInstance();
          final lib = PromptLibrary.fromJson(
            jsonDecode(File(kPromptLibraryAsset).readAsStringSync())
                as Map<String, dynamic>,
          );
          tester.view
            ..physicalSize = const Size(375, 812) * 2
            ..devicePixelRatio = 2;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                promptLibraryProvider.overrideWith((_) => lib),
                interviewPromptsEnabledProvider.overrideWith((_) async => true),
                promptsClockProvider.overrideWithValue(
                  () => DateTime(2026, 11, 26),
                ),
                familyRepositoryProvider.overrideWithValue(
                  DemoFamilyRepository(),
                ),
                storyRepositoryProvider.overrideWithValue(
                  DemoStoryRepository(),
                ),
                settingsRepositoryProvider.overrideWithValue(
                  SettingsRepository(prefs),
                ),
                savedPromptsStoreProvider.overrideWith(
                  (_) async => SavedPromptsStore(prefs),
                ),
                answeredPromptsProvider.overrideWith(
                  (_, _) => const {'childhood_street': 'Sample story'},
                ),
              ],
              child: ScreenUtilInit(
                designSize: AppDimens.designSize,
                builder: (context, _) => MaterialApp(
                  debugShowCheckedModeBanner: false,
                  locale: Locale(locale),
                  theme: AppTheme.light,
                  darkTheme: AppTheme.dark,
                  themeMode: mode,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(
                        screen.startsWith('recordlarge') ? 1.6 : 1,
                      ),
                    ),
                    child: child!,
                  ),
                  home: screen.startsWith('record')
                      ? Builder(
                          builder: (context) {
                            final q = lib.byId('childhood_games')!.text(locale);
                            return RecordView(
                              buttonState: RecordButtonState.idle,
                              elapsed: Duration.zero,
                              levels: const [],
                              narratorName: 'Sitto Amina',
                              draftSaved: false,
                              canFinish: false,
                              topicLabel: 'Childhood & first home',
                              promptText: q.question,
                              promptFollowUp: q.followUps.join(' '),
                              onDifferentQuestion: () {},
                              onMoreQuestions: () {},
                              onClose: () {},
                              onToggle: () {},
                              onPickNarrator: () {},
                              onPickTopic: () {},
                              onDone: () {},
                            );
                          },
                        )
                      : screen == 'feed'
                      ? const StoryFeedPage()
                      : screen == 'page'
                      ? const PromptsPage()
                      : Scaffold(
                          body: Padding(
                            padding: EdgeInsets.all(AppDimens.lg),
                            child: const SafeArea(
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: WeeklyPromptCard(),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (screen == 'recordlargebottom') {
            await tester.drag(find.byType(ListView), const Offset(0, -900));
            await tester.pumpAndSettle();
          }
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('shots/real_font_$variant.png'),
          );
        });
      }
    }
  }
}
