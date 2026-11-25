import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/router/app_routes.dart';
import 'package:family_stories/features/recording/data/memory_draft_store.dart';
import 'package:family_stories/features/recording/data/recorder_service.dart';
import 'package:family_stories/features/recording/presentation/launch_recovery_listener.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Recorder implements RecorderService {
  _Recorder(this.status);
  final RecorderStatus status;
  @override
  RecorderState get state => RecorderState(status: status);
  @override
  Stream<RecorderState> watch() => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

StoryDraft _draft(DraftStatus status) => StoryDraft(
  id: 'd1',
  updatedAt: DateTime(2026, 11, 24, 20, 40),
  status: status,
  segments: const [DraftSegment(path: 'a.wav', durationMs: 1000, closed: true)],
);

Future<GoRouter> _pump(
  WidgetTester t, {
  required List<StoryDraft> drafts,
  RecorderStatus recorder = RecorderStatus.idle,
  String start = AppRoutes.home,
}) async {
  final store = MemoryDraftStore();
  for (final d in drafts) {
    await store.save(d);
  }
  final router = GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, _) => const Text('feed'),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, _) => const Text('welcome'),
      ),
      GoRoute(
        path: '/record/continue',
        builder: (context, _) => const Text('continue screen'),
      ),
    ],
  );
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        draftStoreProvider.overrideWithValue(store),
        recorderServiceProvider.overrideWithValue(_Recorder(recorder)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) =>
            LaunchRecoveryListener(router: router, child: child!),
      ),
    ),
  );
  await t.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('launch with an interrupted draft opens Continue once', (
    t,
  ) async {
    final router = await _pump(t, drafts: [_draft(DraftStatus.interrupted)]);
    expect(find.text('continue screen'), findsOneWidget);
    // Closing it does not bring it back during the same launch.
    router.pop();
    await t.pumpAndSettle();
    expect(find.text('continue screen'), findsNothing);
    expect(find.text('feed'), findsOneWidget);
    router.go(AppRoutes.home);
    await t.pumpAndSettle();
    expect(find.text('continue screen'), findsNothing);
  });

  testWidgets('no interrupted draft: nothing opens', (t) async {
    await _pump(
      t,
      drafts: [_draft(DraftStatus.finished), _draft(DraftStatus.recording)],
    );
    expect(find.text('continue screen'), findsNothing);
    expect(find.text('feed'), findsOneWidget);
  });

  testWidgets('never while a take is live', (t) async {
    await _pump(
      t,
      drafts: [_draft(DraftStatus.interrupted)],
      recorder: RecorderStatus.recording,
    );
    expect(find.text('continue screen'), findsNothing);
  });

  testWidgets('waits through onboarding, opens when home is reached', (
    t,
  ) async {
    final router = await _pump(
      t,
      drafts: [_draft(DraftStatus.interrupted)],
      start: '/onboarding',
    );
    expect(find.text('welcome'), findsOneWidget);
    expect(find.text('continue screen'), findsNothing);
    router.go(AppRoutes.home);
    await t.pumpAndSettle();
    expect(find.text('continue screen'), findsOneWidget);
  });
}
