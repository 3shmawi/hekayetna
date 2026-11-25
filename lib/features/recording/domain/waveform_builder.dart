import 'dart:math' as math;

/// Collects loudness samples while recording (one value per 250 ms) and
/// reduces them to the fixed 64-bar waveform stored with a story (spec 04).
class WaveformAccumulator {
  WaveformAccumulator({
    this.bars = 64,
    this.sampleInterval = const Duration(milliseconds: 250),
  });

  final int bars;
  final Duration sampleInterval;
  final List<double> _samples = [];
  double _peak = 0;
  Duration _bucketStart = Duration.zero;
  bool _hasBucket = false;

  /// Number of finished 250 ms samples.
  int get sampleCount => _samples.length;

  /// Adds a level in 0..1 observed at [at] (time since the take started,
  /// paused time excluded). Levels outside 0..1 and NaN are clamped.
  void add(double level, Duration at) {
    final v = level.isNaN ? 0.0 : level.clamp(0.0, 1.0);
    if (!_hasBucket) {
      _bucketStart = at;
      _hasBucket = true;
    }
    if (at - _bucketStart >= sampleInterval) {
      _samples.add(_peak);
      _peak = 0;
      _bucketStart = at;
    }
    _peak = math.max(_peak, v);
  }

  void reset() {
    _samples.clear();
    _peak = 0;
    _hasBucket = false;
    _bucketStart = Duration.zero;
  }

  /// [bars] integers in 0..100, or null when nothing was captured. Each bar
  /// is the peak of an equal slice of the take; short takes are stretched.
  List<int>? build() {
    final all = [..._samples, if (_hasBucket) _peak];
    if (all.isEmpty) return null;
    final out = <int>[];
    for (var i = 0; i < bars; i++) {
      final from = (i * all.length / bars).floor();
      var to = ((i + 1) * all.length / bars).ceil();
      if (to <= from) to = from + 1;
      var peak = 0.0;
      for (var j = from; j < math.min(to, all.length); j++) {
        peak = math.max(peak, all[j]);
      }
      out.add((peak * 100).round().clamp(0, 100));
    }
    return out;
  }
}

/// Maps a decibel reading (the `record` plugin reports roughly -160..0) to
/// 0..1, treating -60 dB and below as silence.
double levelFromDecibels(double db) {
  if (db.isNaN) return 0;
  return ((db + 60) / 60).clamp(0.0, 1.0);
}
