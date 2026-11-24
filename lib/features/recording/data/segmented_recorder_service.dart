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
  }) : _now = now ?? DateTime.now;

  final DraftStore _draftStore;
  final SegmentRecorder _recorder;
  final DateTime Function() _now;
  final Duration rotationInterval;
  final Duration flushInterval;

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
  Future<void> pause() async {
    final next = RecorderTransitions.pause(_state);
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

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_state.status != RecorderStatus.recording) return;
      final now = _now();
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
    await _recorder.dispose();
    await _controller.close();
  }
}
