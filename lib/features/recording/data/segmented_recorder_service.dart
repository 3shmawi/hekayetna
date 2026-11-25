import 'dart:async';

import 'package:family_stories/features/recording/data/draft_store.dart';
import 'package:family_stories/features/recording/data/recorder_service.dart';
import 'package:family_stories/features/recording/data/segment_recorder.dart';
import 'package:family_stories/features/stories/data/models.dart';

/// Segmented capture coordinated with the draft index (spec 02). A take is a
/// list of WAV segments: a new segment starts on start, on every resume, and
/// every [rotationInterval] of continuous recording. The index is written
/// when recording starts (before the recorder, AC-1), on every rotation,
/// pause and resume, and every [flushInterval] while recording, so a kill
/// never loses more than the open segment.
///
/// Rotation stops the old file and then starts the next: one AudioRecorder
/// cannot overlap two files. The gap is tens of milliseconds, which the spec
/// explicitly allows (< 50 ms, documented in the PR).
class SegmentedRecorderService implements RecorderService {
  SegmentedRecorderService({
    required this._draftStore,
    required this._recorder,
    DateTime Function()? now,
    this.rotationInterval = const Duration(seconds: 30),
    this.flushInterval = const Duration(seconds: 5),
    this.freeBytes,
    this.minFreeBytes = 50 * 1024 * 1024,
    this.storageCheckInterval = const Duration(seconds: 30),
  }) : _now = now ?? DateTime.now {
    _stops = _recorder.unexpectedStops.listen(_onUnexpectedStop);
  }

  final DraftStore _draftStore;
  final SegmentRecorder _recorder;
  final DateTime Function() _now;
  final Duration rotationInterval;
  final Duration flushInterval;

  /// Free space on the drafts volume, in bytes; null when unknown. Injected
  /// because reading free space needs a platform call (see the PR).
  final Future<int?> Function()? freeBytes;
  final int minFreeBytes;
  final Duration storageCheckInterval;
  StreamSubscription<SegmentStopReason>? _stops;
  DateTime? _lastStorageCheck;

  final _controller = StreamController<RecorderState>.broadcast();
  RecorderState _state = const RecorderState(status: RecorderStatus.idle);
  Timer? _ticker;
  DateTime? _segmentStartedAt;
  DateTime? _lastFlush;

  String? _narratorPersonId;
  String? _topic;
  String? _promptId;

  void _emit(RecorderState next) {
    _state = next;
    _controller.add(next);
  }

  @override
  RecorderState get state => _state;

  @override
  Stream<RecorderState> watch() => _controller.stream;

  @override
  Future<bool> ensurePermission() => _recorder.hasPermission();

  @override
  Future<void> start({
    required String draftId,
    String? narratorPersonId,
    String? topic,
    String? promptId,
  }) async {
    final next = RecorderTransitions.start(_state, draftId);
    if (identical(next, _state)) return;
    if (await _storageLow()) {
      _emit(RecorderTransitions.fail(_state, storageFullError));
      return;
    }
    _narratorPersonId = narratorPersonId;
    _topic = topic;
    _promptId = promptId;
    final path = await _draftStore.newSegmentPath(draftId);
    final segment = DraftSegment(path: path, durationMs: 0);
    // AC-1: the draft is in the index BEFORE the recorder starts.
    await _saveDraft(draftId, DraftStatus.recording, [segment]);
    _segmentStartedAt = _now();
    _lastFlush = _segmentStartedAt;
    await _recorder.start(path);
    _emit(next.copyWith(segments: [segment]));
    _startTicker();
  }

  @override
  Future<void> continueDraft(String draftId) async {
    final next = RecorderTransitions.start(_state, draftId);
    if (identical(next, _state)) return;
    final draft = await _draftStore.get(draftId);
    if (draft == null) {
      _emit(
        RecorderTransitions.fail(_state, RecorderService.continueMissingError),
      );
      return;
    }
    if (await _storageLow()) {
      _emit(RecorderTransitions.fail(_state, storageFullError));
      return;
    }
    _narratorPersonId = draft.narratorPersonId;
    _topic = draft.topic;
    _promptId = draft.promptId;
    // An interrupted draft's last segment was re-measured on launch; treat
    // every kept segment as closed.
    final kept = [
      for (final seg in draft.segments)
        if (seg.durationMs > 0) seg.copyWith(closed: true),
    ];
    final path = await _draftStore.newSegmentPath(draftId);
    final segments = [...kept, DraftSegment(path: path, durationMs: 0)];
    // Indexed before capture starts, like a fresh take (AC-1).
    await _saveDraft(draftId, DraftStatus.recording, segments);
    _segmentStartedAt = _now();
    _lastFlush = _segmentStartedAt;
    await _recorder.start(path);
    _emit(next.copyWith(segments: segments, elapsed: _totalDuration(kept)));
    _startTicker();
  }

  /// `RecorderState.error` value when recording could not start for lack of
  /// space; the screen maps it to `AppFailure.storageFull`.
  static const storageFullError = 'storage_full';

  Future<bool> _storageLow() async {
    final free = await freeBytes?.call();
    return free != null && free < minFreeBytes;
  }

  /// Capture ended without the app asking: auto-pause, keep the draft and
  /// never auto-resume (spec 02).
  void _onUnexpectedStop(SegmentStopReason reason) {
    if (_state.status != RecorderStatus.recording) return;
    unawaited(pause(reason: PauseReason.interruption));
  }

  @override
  Future<void> pause({PauseReason reason = PauseReason.user}) async {
    final next = RecorderTransitions.pause(_state, reason: reason);
    if (identical(next, _state)) return;
    final closed = await _closeOpenSegment();
    _ticker?.cancel();
    await _saveDraft(_state.draftId!, DraftStatus.paused, closed);
    _emit(next.copyWith(segments: closed, elapsed: _totalDuration(closed)));
  }

  @override
  Future<void> resume() async {
    final next = RecorderTransitions.resume(_state);
    if (identical(next, _state)) return;
    final draftId = _state.draftId!;
    final path = await _draftStore.newSegmentPath(draftId);
    final segments = [
      ..._state.segments,
      DraftSegment(path: path, durationMs: 0),
    ];
    _segmentStartedAt = _now();
    _lastFlush = _segmentStartedAt;
    await _recorder.start(path);
    await _saveDraft(draftId, DraftStatus.recording, segments);
    _emit(next.copyWith(segments: segments));
    _startTicker();
  }

  @override
  Future<void> stop() async {
    final next = RecorderTransitions.stop(_state);
    if (identical(next, _state)) return;
    final closed = await _closeOpenSegment();
    _ticker?.cancel();
    await _saveDraft(_state.draftId!, DraftStatus.finished, closed);
    _emit(next.copyWith(segments: closed, elapsed: _totalDuration(closed)));
  }

  @override
  Future<void> discard() async {
    try {
      await _recorder.stop();
    } on Exception catch (_) {
      // Already stopped; discarding must never throw.
    }
    _ticker?.cancel();
    _emit(RecorderTransitions.discard(_state));
  }

  /// Stops the recorder and marks the open segment closed with its measured
  /// duration. No-op when there is no open segment (e.g. stop from paused).
  Future<List<DraftSegment>> _closeOpenSegment() async {
    final segments = [..._state.segments];
    if (segments.isEmpty || segments.last.closed) return segments;
    await _recorder.stop();
    final ms = _now().difference(_segmentStartedAt!).inMilliseconds;
    segments[segments.length - 1] = segments.last.copyWith(
      durationMs: ms,
      closed: true,
    );
    return segments;
  }

  Future<void> _rotate() async {
    if (_state.status != RecorderStatus.recording) return;
    final closed = await _closeOpenSegment();
    final draftId = _state.draftId!;
    final path = await _draftStore.newSegmentPath(draftId);
    final segments = [...closed, DraftSegment(path: path, durationMs: 0)];
    _segmentStartedAt = _now();
    _lastFlush = _segmentStartedAt;
    await _recorder.start(path);
    await _saveDraft(draftId, DraftStatus.recording, segments);
    _emit(_state.copyWith(segments: segments));
  }

  Future<void> _pauseIfStorageLow() async {
    if (_state.status == RecorderStatus.recording && await _storageLow()) {
      await pause(reason: PauseReason.storage);
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_state.status != RecorderStatus.recording) return;
      final now = _now();
      if (freeBytes != null &&
          now.difference(_lastStorageCheck ?? _segmentStartedAt!) >=
              storageCheckInterval) {
        _lastStorageCheck = now;
        unawaited(_pauseIfStorageLow());
      }
      final openAge = now.difference(_segmentStartedAt!);
      if (openAge >= rotationInterval) {
        unawaited(_rotate());
        return;
      }
      final segments = [..._state.segments];
      if (segments.isNotEmpty && !segments.last.closed) {
        segments[segments.length - 1] = segments.last.copyWith(
          durationMs: openAge.inMilliseconds,
        );
      }
      if (now.difference(_lastFlush!) >= flushInterval) {
        _lastFlush = now;
        unawaited(_saveDraft(_state.draftId!, DraftStatus.recording, segments));
      }
      _emit(
        _state.copyWith(segments: segments, elapsed: _totalDuration(segments)),
      );
    });
  }

  Duration _totalDuration(List<DraftSegment> segments) => segments.fold(
    Duration.zero,
    (sum, s) => sum + Duration(milliseconds: s.durationMs),
  );

  Future<void> _saveDraft(
    String draftId,
    DraftStatus status,
    List<DraftSegment> segments,
  ) async {
    final existing = await _draftStore.get(draftId);
    await _draftStore.save(
      StoryDraft(
        id: draftId,
        segments: segments,
        status: status,
        narratorPersonId: _narratorPersonId ?? existing?.narratorPersonId,
        topic: _topic ?? existing?.topic,
        promptId: _promptId ?? existing?.promptId,
        createdAt: existing?.createdAt,
        updatedAt: _now(),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    _ticker?.cancel();
    await _stops?.cancel();
    await _recorder.dispose();
    await _controller.close();
  }
}
