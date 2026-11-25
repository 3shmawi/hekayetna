import 'package:family_stories/features/recording/domain/waveform_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WaveformAccumulator', () {
    test('nothing captured gives null', () {
      expect(WaveformAccumulator().build(), isNull);
    });

    test('always 64 values in 0..100', () {
      final w = WaveformAccumulator();
      for (var i = 0; i < 1000; i++) {
        w.add((i % 10) / 9, Duration(milliseconds: i * 100));
      }
      final out = w.build()!;
      expect(out, hasLength(64));
      expect(out.every((v) => v >= 0 && v <= 100), isTrue);
    });

    test('a short take is stretched to 64 bars', () {
      final w = WaveformAccumulator()..add(0.5, Duration.zero);
      expect(w.build(), everyElement(50));
    });

    test('keeps the peak of each 250 ms slice', () {
      final w = WaveformAccumulator()
        ..add(0.2, Duration.zero)
        ..add(0.9, const Duration(milliseconds: 100))
        ..add(0.1, const Duration(milliseconds: 200))
        ..add(0.3, const Duration(milliseconds: 300));
      expect(w.sampleCount, 1);
      final out = w.build()!;
      expect(out.first, 90);
      expect(out.last, 30);
    });

    test('clamps hostile values and NaN', () {
      final w = WaveformAccumulator()
        ..add(double.nan, Duration.zero)
        ..add(5, const Duration(milliseconds: 300))
        ..add(-3, const Duration(milliseconds: 600))
        ..add(double.infinity, const Duration(milliseconds: 900));
      expect(w.build()!.every((v) => v >= 0 && v <= 100), isTrue);
    });

    test('reset clears the take', () {
      final w = WaveformAccumulator()
        ..add(1, Duration.zero)
        ..reset();
      expect(w.build(), isNull);
    });
  });

  test('levelFromDecibels maps -60..0 dB to 0..1', () {
    expect(levelFromDecibels(0), 1);
    expect(levelFromDecibels(-30), closeTo(0.5, 1e-9));
    expect(levelFromDecibels(-60), 0);
    expect(levelFromDecibels(-160), 0);
    expect(levelFromDecibels(double.nan), 0);
    expect(levelFromDecibels(12), 1);
  });
}
