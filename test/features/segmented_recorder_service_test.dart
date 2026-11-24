import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:family_stories/features/recording/data/file_draft_store.dart';
import 'package:family_stories/features/recording/data/memory_draft_store.dart';
import 'package:family_stories/features/recording/data/recorder_service.dart';
import 'package:family_stories/features/recording/data/segment_recorder.dart';
import 'package:family_stories/features/recording/data/segmented_recorder_service.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSegmentRecorder implements SegmentRecorder {
  FakeSegmentRecorder({this.onStart});

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
