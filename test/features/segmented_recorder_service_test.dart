import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:family_stories/features/recording/data/file_draft_store.dart';
import 'package:family_stories/features/recording/data/memory_draft_store.dart';
import 'package:family_stories/features/recording/data/recorder_service.dart';
import 'package:family_stories/features/recording/data/segment_recorder.dart';
import 'package:family_stories/features/recording/data/segmented_recorder_service.dart';
import 'package:family_stories/features/recording/data/storage_space.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSegmentRecorder implements SegmentRecorder {
  FakeSegmentRecorder({this.onStart});

  final _stops = StreamController<SegmentStopReason>.broadcast();

  /// Simulates the OS ending capture (call, route change, error).
  void emitStop(SegmentStopReason reason) => _stops.add(reason);

  @override
  Stream<SegmentStopReason> get unexpectedStops => _stops.stream;

  final Future<void> Function(String path)? onStart;
  final startedPaths = <String>[];
  int stopCalls = 0;
  String? activePath;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> start(String path) async {
    startedPaths.add(path);
    activePath = path;
    await onStart?.call(path);
  }

  @override
  Future<String?> stop() async {
    stopCalls++;
    final p = activePath;
    activePath = null;
    return p;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  continueDraftTests();
  interruptionTests();
  storageSpaceTests();
  group('AC-1: the draft is indexed before the first second of audio', () {
    late Directory dir;
    late FileDraftStore store;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('segmented_test');
      store = FileDraftStore(directoryPath: dir.path);
    });

    tearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });

    test('start writes a recording draft with an open segment first', () async {
      StoryDraft? seenAtRecorderStart;
      final recorder = FakeSegmentRecorder(
        onStart: (_) async => seenAtRecorderStart = await store.get('d1'),
      );
      final service = SegmentedRecorderService(
        draftStore: store,
        recorder: recorder,
      );
      await service.start(draftId: 'd1', narratorPersonId: 'p1', topic: 'war');

      // The index write landed BEFORE the recorder was asked to start.
      expect(seenAtRecorderStart, isNotNull);
      expect(seenAtRecorderStart!.status, DraftStatus.recording);
      expect(seenAtRecorderStart!.segments, hasLength(1));

      final draft = (await store.get('d1'))!;
      expect(draft.status, DraftStatus.recording);
      expect(draft.segments.single.closed, isFalse);
      expect(draft.segments.single.path, recorder.startedPaths.single);
      expect(draft.segments.single.path, startsWith('${dir.path}/d1/'));
      expect(draft.narratorPersonId, 'p1');
      expect(draft.topic, 'war');
      await service.dispose();
    });
  });

  group('AC-2: rotation and resume segmentation (fake clock)', () {
    test('segments rotate every 30 s and durations add up', () {
      fakeAsync((async) {
        final store = MemoryDraftStore();
        final recorder = FakeSegmentRecorder();
        final clock = async.getClock(DateTime.utc(2026, 11, 24, 12));
        final service = SegmentedRecorderService(
          draftStore: store,
          recorder: recorder,
          now: clock.now,
        );
        unawaited(service.start(draftId: 'd1'));
        async.flushMicrotasks();
        expect(service.state.segments, hasLength(1));

        async
          ..elapse(const Duration(seconds: 31))
          ..flushMicrotasks();
        // One rotation: first segment closed at 30 s, second now open.
        expect(service.state.segments, hasLength(2));
        expect(service.state.segments[0].closed, isTrue);
        expect(service.state.segments[0].durationMs, 30000);
        expect(recorder.startedPaths, hasLength(2));

        async.elapse(const Duration(seconds: 5));
        unawaited(service.stop());
        async.flushMicrotasks();

        expect(service.state.status, RecorderStatus.stopped);
        expect(service.state.segments, hasLength(2));
        expect(service.state.segments.every((s) => s.closed), isTrue);
        // 36 s of fake recording; durations add up within the spec's 0.5 s.
        final totalMs = service.state.segments.fold<int>(
          0,
          (sum, s) => sum + s.durationMs,
        );
        expect((totalMs - 36000).abs(), lessThanOrEqualTo(500));

        StoryDraft? draft;
        unawaited(store.get('d1').then((d) => draft = d));
        async.flushMicrotasks();
        expect(draft!.status, DraftStatus.finished);
        expect(draft!.segments, hasLength(2));
        unawaited(service.dispose());
        async.flushMicrotasks();
      });
    });

    test('pause closes the segment; resume appends a new one', () {
      fakeAsync((async) {
        final store = MemoryDraftStore();
        final recorder = FakeSegmentRecorder();
        final clock = async.getClock(DateTime.utc(2026, 11, 24, 12));
        final service = SegmentedRecorderService(
          draftStore: store,
          recorder: recorder,
          now: clock.now,
        );
        unawaited(service.start(draftId: 'd1'));
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 10));
        unawaited(service.pause());
        async.flushMicrotasks();
        expect(service.state.status, RecorderStatus.paused);
        expect(service.state.segments.single.closed, isTrue);
        expect(service.state.segments.single.durationMs, 10000);

        StoryDraft? paused;
        unawaited(store.get('d1').then((d) => paused = d));
        async.flushMicrotasks();
        expect(paused!.status, DraftStatus.paused);

        unawaited(service.resume());
        async.flushMicrotasks();
        expect(service.state.status, RecorderStatus.recording);
        expect(service.state.segments, hasLength(2));
        expect(service.state.segments.last.closed, isFalse);
        expect(recorder.startedPaths, hasLength(2));

        // The timer continues from the kept duration.
        async.elapse(const Duration(seconds: 4));
        unawaited(service.stop());
        async.flushMicrotasks();
        expect(service.state.segments[1].durationMs, 4000);
        expect(service.state.elapsed, const Duration(seconds: 14));
        unawaited(service.dispose());
        async.flushMicrotasks();
      });
    });

    test('the index is rewritten every 5 s while recording', () {
      fakeAsync((async) {
        final store = MemoryDraftStore();
        final recorder = FakeSegmentRecorder();
        final clock = async.getClock(DateTime.utc(2026, 11, 24, 12));
        final service = SegmentedRecorderService(
          draftStore: store,
          recorder: recorder,
          now: clock.now,
        );
        unawaited(service.start(draftId: 'd1'));
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 11))
          ..flushMicrotasks();
        StoryDraft? draft;
        unawaited(store.get('d1').then((d) => draft = d));
        async.flushMicrotasks();
        // Flushes landed at 5 s and 10 s; the live state is ahead of the index.
        expect(draft!.segments.single.durationMs, 10000);
        expect(service.state.segments.single.durationMs, 11000);
        unawaited(service.dispose());
        async.flushMicrotasks();
      });
    });

    test('a second start while recording is rejected', () {
      fakeAsync((async) {
        final store = MemoryDraftStore();
        final recorder = FakeSegmentRecorder();
        final service = SegmentedRecorderService(
          draftStore: store,
          recorder: recorder,
        );
        unawaited(service.start(draftId: 'd1'));
        async.flushMicrotasks();
        unawaited(service.start(draftId: 'd2'));
        async.flushMicrotasks();
        expect(recorder.startedPaths, hasLength(1));
        expect(service.state.draftId, 'd1');
        unawaited(service.dispose());
        async.flushMicrotasks();
      });
    });

    test('discard returns to idle without touching the stored draft', () {
      fakeAsync((async) {
        final store = MemoryDraftStore();
        final recorder = FakeSegmentRecorder();
        final service = SegmentedRecorderService(
          draftStore: store,
          recorder: recorder,
        );
        unawaited(service.start(draftId: 'd1'));
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 2));
        unawaited(service.discard());
        async.flushMicrotasks();
        expect(service.state.status, RecorderStatus.idle);
        expect(service.state.draftId, isNull);

        StoryDraft? draft;
        unawaited(store.get('d1').then((d) => draft = d));
        async.flushMicrotasks();
        expect(draft, isNotNull); // the screen deletes it explicitly
        unawaited(service.dispose());
        async.flushMicrotasks();
      });
    });
  });
}

void interruptionTests() {
  group('AC-5: interruptions pause and nothing auto-resumes', () {
    test('a call pauses the take, keeps the draft and the reason', () async {
      final recorder = FakeSegmentRecorder();
      final store = MemoryDraftStore();
      final service = SegmentedRecorderService(
        draftStore: store,
        recorder: recorder,
      );
      await service.start(draftId: 'd1');
      recorder.emitStop(SegmentStopReason.interruption);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(service.state.status, RecorderStatus.paused);
      expect(service.state.pauseReason, PauseReason.interruption);
      final draft = (await store.get('d1'))!;
      expect(draft.status, DraftStatus.paused);
      expect(draft.segments.single.closed, isTrue);

      // Nothing resumes by itself, even if the OS reports more events.
      recorder.emitStop(SegmentStopReason.routeChange);
      await Future<void>.delayed(Duration.zero);
      expect(service.state.status, RecorderStatus.paused);
      expect(recorder.startedPaths, hasLength(1));

      await service.resume();
      expect(service.state.status, RecorderStatus.recording);
      expect(service.state.pauseReason, isNull);
      await service.dispose();
    });

    test('unplugged headphones and capture errors also pause', () async {
      for (final reason in [
        SegmentStopReason.routeChange,
        SegmentStopReason.error,
      ]) {
        final recorder = FakeSegmentRecorder();
        final service = SegmentedRecorderService(
          draftStore: MemoryDraftStore(),
          recorder: recorder,
        );
        await service.start(draftId: 'd1');
        recorder.emitStop(reason);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(service.state.status, RecorderStatus.paused);
        await service.dispose();
      }
    });

    test('a user pause records the user as the reason', () async {
      final service = SegmentedRecorderService(
        draftStore: MemoryDraftStore(),
        recorder: FakeSegmentRecorder(),
      );
      await service.start(draftId: 'd1');
      await service.pause();
      expect(service.state.pauseReason, PauseReason.user);
      await service.dispose();
    });
  });

  group('AC-10: low storage', () {
    test(
      'start fails with storage_full under 50 MB and writes nothing',
      () async {
        final store = MemoryDraftStore();
        final recorder = FakeSegmentRecorder();
        final service = SegmentedRecorderService(
          draftStore: store,
          recorder: recorder,
          freeBytes: () async => 10 * 1024 * 1024,
        );
        await service.start(draftId: 'd1');
        expect(service.state.status, RecorderStatus.failed);
        expect(service.state.error, SegmentedRecorderService.storageFullError);
        expect(await store.list(), isEmpty);
        expect(recorder.startedPaths, isEmpty);
        await service.dispose();
      },
    );

    test('recording pauses with reason storage when space runs out', () {
      fakeAsync((async) {
        var free = 500 * 1024 * 1024;
        final recorder = FakeSegmentRecorder();
        final service = SegmentedRecorderService(
          draftStore: MemoryDraftStore(),
          recorder: recorder,
          now: () => DateTime(2026).add(async.elapsed),
          freeBytes: () async => free,
        );
        unawaited(service.start(draftId: 'd1'));
        async.elapse(const Duration(seconds: 10));
        expect(service.state.status, RecorderStatus.recording);
        free = 20 * 1024 * 1024;
        async.elapse(const Duration(seconds: 25));
        expect(service.state.status, RecorderStatus.paused);
        expect(service.state.pauseReason, PauseReason.storage);
      });
    });
  });
}

void storageSpaceTests() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('StorageSpace', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(
      () => messenger.setMockMethodCallHandler(StorageSpace.channel, null),
    );

    test('returns the native free-byte count', () async {
      messenger.setMockMethodCallHandler(
        StorageSpace.channel,
        (call) async => call.method == 'freeBytes' ? 123456 : null,
      );
      expect(await StorageSpace.freeBytes(), 123456);
    });

    test('unknown (null) when the platform has no handler or fails', () async {
      expect(await StorageSpace.freeBytes(), isNull);
      messenger.setMockMethodCallHandler(
        StorageSpace.channel,
        (_) async => throw PlatformException(code: 'unavailable'),
      );
      expect(await StorageSpace.freeBytes(), isNull);
    });
  });
}

void continueDraftTests() {
  group('continueDraft (RecordResume)', () {
    test(
      'keeps kept segments, appends an open one, timer carries on',
      () async {
        final store = MemoryDraftStore();
        await store.save(
          StoryDraft(
            id: 'd1',
            updatedAt: DateTime(2026),
            status: DraftStatus.interrupted,
            narratorPersonId: 'p1',
            topic: 'war',
            segments: const [
              DraftSegment(path: 'a.wav', durationMs: 30000, closed: true),
              DraftSegment(path: 'b.wav', durationMs: 15000),
              DraftSegment(path: 'empty.wav', durationMs: 0),
            ],
          ),
        );
        StoryDraft? seenAtRecorderStart;
        final recorder = FakeSegmentRecorder(
          onStart: (_) async => seenAtRecorderStart = await store.get('d1'),
        );
        final service = SegmentedRecorderService(
          draftStore: store,
          recorder: recorder,
        );
        await service.continueDraft('d1');

        // Indexed as recording BEFORE capture starts (AC-1).
        expect(seenAtRecorderStart!.status, DraftStatus.recording);
        final draft = (await store.get('d1'))!;
        expect(draft.segments.map((s) => s.path).take(2), ['a.wav', 'b.wav']);
        expect(draft.segments.map((s) => s.closed), [true, true, false]);
        expect(draft.segments.last.path, recorder.startedPaths.single);
        // The empty leftover is dropped; narrator and topic are kept.
        expect(draft.segments, hasLength(3));
        expect(draft.narratorPersonId, 'p1');
        expect(draft.topic, 'war');
        expect(service.state.status, RecorderStatus.recording);
        expect(service.state.draftId, 'd1');
        expect(service.state.elapsed, const Duration(seconds: 45));
        await service.dispose();
      },
    );

    test(
      'a missing draft fails with a clear error and records nothing',
      () async {
        final recorder = FakeSegmentRecorder();
        final service = SegmentedRecorderService(
          draftStore: MemoryDraftStore(),
          recorder: recorder,
        );
        await service.continueDraft('nope');
        expect(service.state.status, RecorderStatus.failed);
        expect(service.state.error, RecorderService.continueMissingError);
        expect(recorder.startedPaths, isEmpty);
        await service.dispose();
      },
    );

    test('stop after continuing finishes with all segments closed', () async {
      final store = MemoryDraftStore();
      await store.save(
        StoryDraft(
          id: 'd2',
          updatedAt: DateTime(2026),
          status: DraftStatus.interrupted,
          segments: const [
            DraftSegment(path: 'a.wav', durationMs: 20000, closed: true),
          ],
        ),
      );
      final service = SegmentedRecorderService(
        draftStore: store,
        recorder: FakeSegmentRecorder(),
      );
      await service.continueDraft('d2');
      await service.stop();
      final draft = (await store.get('d2'))!;
      expect(draft.status, DraftStatus.finished);
      expect(draft.segments.every((s) => s.closed), isTrue);
      expect(draft.segments.first.path, 'a.wav');
      await service.dispose();
    });
  });
}
