import 'dart:async';

import 'package:family_stories/features/recording/data/recorder_service.dart';
import 'package:record/record.dart';

/// Real microphone capture via the `record` plugin. All state changes pass
/// through RecorderTransitions so behavior matches the unit tests exactly.
class RecordRecorderService implements RecorderService {
  RecordRecorderService({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  final _controller = StreamController<RecorderState>.broadcast();
  RecorderState _state = const RecorderState(status: RecorderStatus.idle);
  Timer? _ticker;

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
  Future<void> start(String filePath) async {
    final next = RecorderTransitions.start(_state, filePath);
    if (identical(next, _state)) return;
    await _recorder.start(const RecordConfig(), path: filePath);
    _emit(next);
    _startTicker();
  }

  @override
  Future<void> pause() async {
    final next = RecorderTransitions.pause(_state);
    if (identical(next, _state)) return;
    await _recorder.pause();
    _emit(next);
  }

  @override
  Future<void> resume() async {
    final next = RecorderTransitions.resume(_state);
    if (identical(next, _state)) return;
    await _recorder.resume();
    _emit(next);
  }

  @override
  Future<String?> stop() async {
    final next = RecorderTransitions.stop(_state);
    if (identical(next, _state)) return _state.filePath;
    final path = await _recorder.stop();
    _ticker?.cancel();
    _emit(next.copyWith(filePath: path ?? _state.filePath));
    return _state.filePath;
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

  void _startTicker() {
    _ticker?.cancel();
    final started = DateTime.now();
    var carried = _state.elapsed;
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_state.status == RecorderStatus.recording) {
        _emit(
          _state.copyWith(
            elapsed: carried + DateTime.now().difference(started),
          ),
        );
      } else {
        carried = _state.elapsed;
      }
    });
  }

  @override
  Future<void> dispose() async {
    _ticker?.cancel();
    await _recorder.dispose();
    await _controller.close();
  }
}
