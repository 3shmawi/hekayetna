import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/auth/auth.dart';
import 'package:family_stories/core/privacy/consent.dart';
import 'package:family_stories/core/privacy/consent_sheet.dart';
import 'package:family_stories/core/router/app_redirect.dart';
import 'package:family_stories/core/router/app_router.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/features/onboarding/data/onboarding.dart';
import 'package:family_stories/features/prompts/data/prompt_flag.dart';
import 'package:family_stories/features/prompts/data/prompt_library_loader.dart';
import 'package:family_stories/features/prompts/data/saved_prompts_store.dart';
import 'package:family_stories/features/prompts/domain/interview_prompt.dart';
import 'package:family_stories/features/prompts/presentation/prompts_page.dart';
import 'package:family_stories/features/prompts/presentation/prompts_providers.dart';
import 'package:family_stories/features/recording/data/memory_draft_store.dart';
import 'package:family_stories/features/recording/data/recorder_service.dart';
import 'package:family_stories/features/recording/presentation/record_page.dart';
import 'package:family_stories/features/settings/data/settings_repository.dart';
import 'package:family_stories/features/settings/presentation/settings_controller.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

class _Recorder implements RecorderService {
  final started = <({String? topic, String? promptId})>[];
  @override
  RecorderState get state => const RecorderState(status: RecorderStatus.idle);
  @override
  Stream<double> get levels => const Stream.empty();
  @override
  List<int>? get waveform => null;
  @override
  Stream<RecorderState> watch() => const Stream.empty();
  @override
  Future<bool> ensurePermission() async => true;
  @override
  Future<void> continueDraft(String draftId) async {}
  @override
  Future<void> start({
    required String draftId,
    String? narratorPersonId,
    String? topic,
    String? promptId,
  }) async => started.add((topic: topic, promptId: promptId));
  @override
  Future<void> pause({PauseReason reason = PauseReason.user}) async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> discard() async {}
  @override
  Future<void> dispose() async {}
}

/// The prompts routes on the app's REAL router and the real RecordPage
/// (spec 07, AC-6, AC-7): the query is read, used with the flag on, and
/// ignored with it off, including a direct visit.
void main() {
  late _Recorder recorder;
  late List<String> events;
  late PromptLibrary lib;

  setUp(() async {
    await loadAppFonts();
    demoModeSignedInOverride = true;
    Auth.user.value = null;
    Onboarding.seen.value = true;
    Consent.analytics.value = ConsentChoice.unknown;
    ConsentListener.neededOverride = false;
    events = [];
    lib = PromptLibrary.fromJson(
      jsonDecode(File(kPromptLibraryAsset).readAsStringSync())
          as Map<String, dynamic>,
    );
  });
  tearDown(() {
    demoModeSignedInOverride = null;
    Auth.user.value = null;
    ConsentListener.neededOverride = null;
    Consent.analytics.value = ConsentChoice.unknown;
    appRouter.go('/');
  });

  Future<void> pump(WidgetTester t, {required bool flag}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    recorder = _Recorder();
    t.view
      ..physicalSize = const Size(1125, 2436)
      ..devicePixelRatio = 3;
    addTearDown(t.view.reset);
    appRouter.go('/stories');
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          draftStoreProvider.overrideWithValue(MemoryDraftStore()),
          recorderServiceProvider.overrideWithValue(recorder),
          settingsRepositoryProvider.overrideWithValue(
            SettingsRepository(prefs),
          ),
          promptLibraryProvider.overrideWith((_) => lib),
          interviewPromptsEnabledProvider.overrideWith((_) async => flag),
          savedPromptsStoreProvider.overrideWith(
            (_) async => SavedPromptsStore(prefs),
          ),
          promptEventsProvider.overrideWithValue((event, [props]) async {
            events.add('$event ${props ?? {}}');
          }),
        ],
        child: AppUi.testWrap(
          ScreenUtilInit(
            designSize: AppDimens.designSize,
            builder: (context, _) => MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: appRouter,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  // The record screen's halo animates forever: pump frames, don't settle.
  Future<void> frames(WidgetTester t) async {
    for (var i = 0; i < 15; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  InterviewPrompt funny() => lib.forTopic('funny_memories').first;

  testWidgets('flag on: /prompts?from=feed opens the page and reports it', (
    t,
  ) async {
    await pump(t, flag: true);
    appRouter.go('/prompts?from=feed');
    await frames(t);
    expect(find.byType(PromptsPage), findsOneWidget);
    expect(events, contains('prompts_opened {from: feed}'));
  });

  testWidgets('flag on: /record query sets the question, topic and draft', (
    t,
  ) async {
    await pump(t, flag: true);
    final p = funny();
    appRouter.go('/record?topic=funny_memories&prompt=${p.id}');
    await frames(t);
    expect(find.byType(RecordPage), findsOneWidget);
    expect(find.text(p.en.question), findsOneWidget);
    expect(find.text(l10nEn.topic_funny_memories), findsOneWidget);
    // The follow-ups show under the question (Record artboard).
    expect(
      find.text(l10nEn.recordThen(p.en.followUps.join(' '))),
      findsOneWidget,
    );
    t.widget<RecordButton>(find.byType(RecordButton)).onPressed();
    await frames(t);
    expect(recorder.started, [(topic: 'funny_memories', promptId: p.id)]);
  });

  testWidgets('flag off: /record query is ignored', (t) async {
    await pump(t, flag: false);
    final p = funny();
    appRouter.go('/record?topic=funny_memories&prompt=${p.id}');
    await frames(t);
    expect(find.byType(RecordPage), findsOneWidget);
    expect(find.text(p.en.question), findsNothing);
    expect(find.text(l10nEn.topic_funny_memories), findsNothing);
    t.widget<RecordButton>(find.byType(RecordButton)).onPressed();
    await frames(t);
    expect(recorder.started, [(topic: null, promptId: null)]);
  });

  testWidgets('flag off: a direct visit to /prompts goes back to the feed', (
    t,
  ) async {
    await pump(t, flag: false);
    appRouter.go('/prompts?from=feed');
    await frames(t);
    expect(find.byType(PromptsPage), findsNothing);
    expect(appRouter.routerDelegate.currentConfiguration.uri.path, '/stories');
    expect(events, isEmpty);
  });
}
