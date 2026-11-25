import 'dart:async';

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/features/family/data/demo_family_repository.dart';
import 'package:family_stories/features/recording/data/memory_draft_store.dart';
import 'package:family_stories/features/recording/data/recorder_service.dart';
import 'package:family_stories/features/recording/presentation/continue_recording_screen.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Recorder implements RecorderService {
  final continued = <String>[];
  bool permission = true;
  @override
  RecorderState get state => const RecorderState(status: RecorderStatus.idle);
  @override
  Stream<RecorderState> watch() => const Stream.empty();
  @override
  Future<bool> ensurePermission() async => permission;
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

StoryDraft _draft(String id, DraftStatus status, DateTime at) => StoryDraft(
  id: id,
  updatedAt: at,
  status: status,
  segments: const [
    DraftSegment(path: 'a.wav', durationMs: 30000, closed: true),
    DraftSegment(path: 'b.wav', durationMs: 20000, closed: true),
  ],
);

Future<(MemoryDraftStore, _Recorder)> _pump(
  WidgetTester t,
  List<StoryDraft> drafts,
) async {
  final store = MemoryDraftStore();
  for (final d in drafts) {
    await store.save(d);
  }
  final recorder = _Recorder();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => unawaited(context.push('/continue')),
            child: const Text('open'),
          ),
        ),
      ),
      GoRoute(path: '/record', builder: (context, _) => const Text('live')),
      GoRoute(
        path: '/continue',
        builder: (context, _) => const ContinueRecordingScreen(),
      ),
      GoRoute(
        path: '/record/preview/:id',
        builder: (context, state) =>
            Text('preview ${state.pathParameters['id']}'),
      ),
    ],
  );
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        draftStoreProvider.overrideWithValue(store),
        recorderServiceProvider.overrideWithValue(recorder),
        familyRepositoryProvider.overrideWithValue(DemoFamilyRepository()),
      ],
      child: ScreenUtilInit(
        designSize: AppDimens.designSize,
        builder: (context, _) => MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    ),
  );
  t.view
    ..physicalSize = const Size(1000, 3000)
    ..devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  return (store, recorder);
}

void main() {
  final now = DateTime.now();

  test('only interrupted drafts are offered, newest first', () {
    final ids = onlyInterrupted([
      _draft('old', DraftStatus.interrupted, DateTime(2026)),
      _draft('new', DraftStatus.interrupted, DateTime(2027)),
      _draft('fin', DraftStatus.finished, DateTime(2028)),
      _draft('rec', DraftStatus.recording, DateTime(2029)),
    ]).map((d) => d.id);
    expect(ids, ['new', 'old']);
  });

  testWidgets('shows the kept recording and its actions', (t) async {
    await _pump(t, [_draft('d1', DraftStatus.interrupted, now)]);
    expect(find.text('Your recording is safe'), findsOneWidget);
    expect(find.text('2 parts · 0:50'), findsOneWidget);
    expect(find.textContaining('today at'), findsOneWidget);
  });

  testWidgets('Continue recording hands the draft to the recorder', (t) async {
    final (_, recorder) = await _pump(t, [
      _draft('d1', DraftStatus.interrupted, now),
    ]);
    await t.tap(find.byKey(const Key('resume_continue_d1')));
    await t.pumpAndSettle();
    expect(recorder.continued, ['d1']);
    expect(find.text('live'), findsOneWidget); // the live record screen
  });

  testWidgets('no microphone permission: nothing starts', (t) async {
    final (_, recorder) = await _pump(t, [
      _draft('d1', DraftStatus.interrupted, now),
    ]);
    recorder.permission = false;
    await t.tap(find.byKey(const Key('resume_continue_d1')));
    await t.pumpAndSettle();
    expect(recorder.continued, isEmpty);
    expect(find.byKey(const Key('resume_continue_d1')), findsOneWidget);
  });

  testWidgets('It is finished marks the draft finished and opens it', (
    t,
  ) async {
    final (store, _) = await _pump(t, [
      _draft('d1', DraftStatus.interrupted, now),
    ]);
    await t.tap(find.byKey(const Key('resume_save_d1')));
    await t.pumpAndSettle();
    expect((await store.get('d1'))!.status, DraftStatus.finished);
    expect(find.text('preview d1'), findsOneWidget);
  });

  testWidgets('Delete asks once, plainly, and only then deletes', (t) async {
    final (store, _) = await _pump(t, [
      _draft('d1', DraftStatus.interrupted, now),
    ]);
    await t.tap(find.byKey(const Key('resume_delete_d1')));
    await t.pumpAndSettle();
    expect(find.text('Delete this recording?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(await store.get('d1'), isNotNull);

    await t.tap(find.byKey(const Key('resume_delete_d1')));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();
    expect(await store.get('d1'), isNull);
    expect(find.text('open'), findsOneWidget); // none left: screen closes
  });
}
