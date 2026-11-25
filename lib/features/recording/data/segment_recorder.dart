import 'package:family_stories/features/recording/domain/waveform_builder.dart';
import 'package:record/record.dart';

/// One segment file of microphone capture. The `record` plugin implements
/// this; tests fake it, so rotation, pause and recovery are unit-testable
/// without a microphone.
/// Why capture ended without the app asking for it.
enum SegmentStopReason {
  /// A call, Siri or another app took the microphone.
  interruption,

  /// The input went away (headphones unplugged).
  routeChange,

  /// Capture or encoding failed.
  error,
}

abstract class SegmentRecorder {
  /// Capture ended on its own. Stops the app asked for never appear here.
  Stream<SegmentStopReason> get unexpectedStops;

  /// Loudness 0..1 about every 100 ms while capturing.
  Stream<double> get levels;
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
  Stream<SegmentStopReason> get unexpectedStops => _recorder
      .onStopped()
      .where((s) => s.reason != RecordStopReason.stop)
      .map(
        (s) => switch (s.reason) {
          RecordStopReason.interruption => SegmentStopReason.interruption,
          RecordStopReason.routeChange => SegmentStopReason.routeChange,
          RecordStopReason.stop ||
          RecordStopReason.error => SegmentStopReason.error,
        },
      );

  @override
  Stream<double> get levels => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 100))
      .map((a) => levelFromDecibels(a.current));

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) => _recorder.start(config, path: path);

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> dispose() => _recorder.dispose();
}
