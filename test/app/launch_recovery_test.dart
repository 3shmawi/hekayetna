import 'dart:async';

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
import 'package:family_stories/features/recording/data/memory_draft_store.dart';
import 'package:family_stories/features/recording/data/recorder_service.dart';
import 'package:family_stories/features/recording/presentation/launch_recovery_listener.dart';
import 'package:family_stories/features/recording/presentation/preview_screen.dart';
import 'package:family_stories/features/recording/presentation/record_screen.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

class _Recorder implements RecorderService {
  _Recorder(this._status);
  final RecorderStatus _status;
  final continued = <String>[];
  @override
  RecorderState get state => RecorderState(
    status: continued.isEmpty ? _status : RecorderStatus.recording,
  );
  @override
  Stream<RecorderState> watch() => const Stream.empty();
  @override
  Future<bool> ensurePermission() async => true;
  @override
  Future<void> continueDraft(String draftId) async => continued.add(draftId);
  @override
  Future<void> start({
    required String draftId,
    String? narratorPersonId,
    String? topic,
    String? promptId,
  }) async {}
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

StoryDraft _draft(DraftStatus status) => StoryDraft(
  id: 'd1',
  updatedAt: DateTime.now().subtract(const Duration(days: 1)),
  status: status,
  segments: const [
    DraftSegment(path: 'a.wav', durationMs: 50000, closed: true),
  ],
);

/// The launch sheet on the app's REAL router and root navigator (the same
/// listener the app shell mounts), over the demo repositories.
void main() {
  late _Recorder recorder;

  setUp(() async {
    await loadAppFonts();
    demoModeSignedInOverride = true;
    Auth.user.value = null;
    Onboarding.seen.value = true;
    Consent.analytics.value = ConsentChoice.unknown;
    ConsentListener.neededOverride = false;
  });
  tearDown(() {
    demoModeSignedInOverride = null;
    Auth.user.value = null;
    Onboarding.seen.value = true;
    ConsentListener.neededOverride = null;
    Consent.analytics.value = ConsentChoice.unknown;
    appRouter.go('/');
  });

  Future<void> pumpApp(
    WidgetTester t, {
    List<StoryDraft> drafts = const [],
    RecorderStatus status = RecorderStatus.idle,
  }) async {
    final store = MemoryDraftStore();
    for (final d in drafts) {
      await store.save(d);
    }
    recorder = _Recorder(status);
    t.view
      ..physicalSize = const Size(1125, 2436)
      ..devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          draftStoreProvider.overrideWithValue(store),
          recorderServiceProvider.overrideWithValue(recorder),
        ],
        child: AppUi.testWrap(
          ScreenUtilInit(
            designSize: AppDimens.designSize,
            builder: (context, _) => MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: appRouter,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => LaunchRecoveryListener(
                router: appRouter,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  final title = l10nEn.resumeTitleNoNarrator;

  testWidgets('opens as a bottom sheet over the feed, once per launch', (
    t,
  ) async {
    await pumpApp(t, drafts: [_draft(DraftStatus.interrupted)]);
    expect(find.text(title), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('The first Om Ali (sample)'), findsOneWidget); // behind
    await t.tap(find.byKey(const Key('resume_close')));
    await t.pumpAndSettle();
    expect(find.text(title), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    appRouter.go('/family');
    await t.pumpAndSettle();
    appRouter.go('/stories');
    await t.pumpAndSettle();
    expect(find.text(title), findsNothing);
  });

  testWidgets('Continue recording goes to the live record tab from stories', (
    t,
  ) async {
    await pumpApp(t, drafts: [_draft(DraftStatus.interrupted)]);
    await t.tap(find.byKey(const Key('resume_continue_d1')));
    await t.pumpAndSettle();
    expect(recorder.continued, ['d1']);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(RecordScreen), findsOneWidget);
  });

  testWidgets('It is finished opens the save screen and keeps the draft', (
    t,
  ) async {
    await pumpApp(t, drafts: [_draft(DraftStatus.interrupted)]);
    final visited = <String>[];
    void note() =>
        visited.add(appRouter.routerDelegate.currentConfiguration.uri.path);
    appRouter.routerDelegate.addListener(note);
    addTearDown(() => appRouter.routerDelegate.removeListener(note));
    await t.tap(find.byKey(const Key('resume_save_d1')));
    await t.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      find.byType(RecordingPreviewScreen),
      findsOneWidget,
      reason: '$visited',
    );
    final store = ProviderScope.containerOf(
      t.element(find.byType(MaterialApp)),
    ).read(draftStoreProvider);
    expect((await store.get('d1'))!.status, DraftStatus.finished);
  });

  testWidgets('no interrupted draft, or a live take: no sheet', (t) async {
    await pumpApp(
      t,
      drafts: [_draft(DraftStatus.finished), _draft(DraftStatus.recording)],
    );
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('never while a take is live', (t) async {
    await pumpApp(
      t,
      drafts: [_draft(DraftStatus.interrupted)],
      status: RecorderStatus.recording,
    );
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('waits through onboarding, then opens on the feed', (t) async {
    Onboarding.seen.value = false;
    await pumpApp(t, drafts: [_draft(DraftStatus.interrupted)]);
    expect(
      appRouter.routerDelegate.currentConfiguration.uri.path,
      isNot('/stories'),
    );
    expect(find.byType(BottomSheet), findsNothing);
    Onboarding.seen.value = true;
    appRouter.go('/'); // what finishing the welcome screens does
    await t.pumpAndSettle();
    expect(find.text(title), findsOneWidget);
  });

  testWidgets('waits for the privacy answer, then opens', (t) async {
    ConsentListener.neededOverride = true;
    await pumpApp(t, drafts: [_draft(DraftStatus.interrupted)]);
    expect(find.text(title), findsNothing);
    Consent.analytics.value = ConsentChoice.denied;
    await t.pumpAndSettle();
    expect(find.text(title), findsOneWidget);
  });
}
