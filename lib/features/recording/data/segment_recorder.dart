import 'package:record/record.dart';

/// One segment file of microphone capture. The `record` plugin implements
/// this; tests fake it, so rotation, pause and recovery are unit-testable
/// without a microphone.
abstract class SegmentRecorder {
  Future<bool> hasPermission();
  Future<void> start(String path);

  /// Closes the current segment file and returns its path (null when the
  /// platform produced nothing).
  Future<String?> stop();
  Future<void> dispose();
}

/// Real capture via the `record` plugin, one file per segment.
class RecordSegmentRecorder implements SegmentRecorder {
  RecordSegmentRecorder({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  /// WAV PCM; 44.1 kHz and mono are the RecordConfig defaults: the spec's
  /// fallback, because record 7.2.0 has no ADTS encoder on either platform
  /// (verified in the pinned record_platform_interface 2.2.0). The plugin's
  /// interruption and audio-route defaults are both `pause` (verified in the
  /// same source), which is what the spec wants.
  static const config = RecordConfig(encoder: AudioEncoder.wav);

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) => _recorder.start(config, path: path);

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> dispose() => _recorder.dispose();
}
