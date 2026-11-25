import 'dart:io';
import 'dart:typed_data';

import 'package:family_stories/features/recording/data/segment_joiner.dart';
import 'package:family_stories/features/recording/data/wav_repair.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// A WAV like the two platforms write it. Android: 44-byte header. iOS-style:
/// Core Audio puts a filler chunk before `data`, so the audio starts later
/// (4096 here), and an unclosed file keeps placeholder sizes. The iOS layout
/// is built from the format description, not captured from a device.
Uint8List wav(
  List<int> pcm, {
  int filler = 0,
  bool placeholderSizes = false,
  int sampleRate = 44100,
}) {
  final headerLen = 12 + 24 + (filler > 0 ? 8 + filler : 0) + 8;
  final b = BytesBuilder();
  final h = ByteData(headerLen);
  void tag(int o, String t) {
    for (var i = 0; i < 4; i++) {
      h.setUint8(o + i, t.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  h.setUint32(
    4,
    placeholderSizes ? 0xFFFFFFFF : headerLen - 8 + pcm.length,
    Endian.little,
  );
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  h
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  var o = 36;
  if (filler > 0) {
    tag(o, 'FLLR');
    h.setUint32(o + 4, filler, Endian.little);
    o += 8 + filler;
  }
  tag(o, 'data');
  h.setUint32(o + 4, placeholderSizes ? 0 : pcm.length, Endian.little);
  b
    ..add(h.buffer.asUint8List())
    ..add(pcm);
  return b.toBytes();
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('join'));
  tearDown(() => dir.deleteSync(recursive: true));

  DraftSegment seg(String name, Uint8List bytes) {
    final f = File('${dir.path}/$name')..writeAsBytesSync(bytes);
    return DraftSegment(path: f.path, durationMs: 1000, closed: true);
  }

  Future<void> expectJoined(
    List<DraftSegment> segs,
    List<int> expectedPcm,
  ) async {
    final out = await SegmentJoiner.join(segs, '${dir.path}/out.wav');
    final bytes = File(out).readAsBytesSync();
    // canonical 44-byte header: the player and the upload both see one
    // plain WAV
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');
    final layout = await WavRepair.layout(File(out));
    expect(layout, isNotNull);
    expect(layout!.dataStart, 44);
    expect(layout.dataBytes, expectedPcm.length);
    expect(bytes.sublist(44), expectedPcm);
    final d = ByteData.sublistView(bytes);
    expect(d.getUint32(4, Endian.little), 36 + expectedPcm.length);
    expect(d.getUint32(40, Endian.little), expectedPcm.length);
  }

  final a = List<int>.generate(2000, (i) => (i * 7) % 256);
  final b = List<int>.generate(1000, (i) => (i * 13) % 256);

  test('44-byte header segments (Android layout)', () async {
    await expectJoined(
      [seg('1.wav', wav(a)), seg('2.wav', wav(b))],
      [...a, ...b],
    );
  });

  test('segment with a filler chunk before data (iOS layout)', () async {
    await expectJoined(
      [seg('1.wav', wav(a, filler: 4040)), seg('2.wav', wav(b, filler: 4040))],
      [...a, ...b],
    );
  });

  test('an unclosed segment with placeholder sizes still joins', () async {
    await expectJoined([
      seg('1.wav', wav(a, filler: 4040, placeholderSizes: true)),
    ], a);
  });

  test(
    'an empty trailing placeholder (length 0, not closed) is skipped',
    () async {
      await expectJoined([
        seg('1.wav', wav(a)),
        DraftSegment(path: '${dir.path}/open.wav', durationMs: 0),
        seg('open2.wav', wav(const [])).copyWith(durationMs: 0, closed: false),
      ], a);
    },
  );

  test('a recorded segment that is missing fails, never truncates', () async {
    final good = seg('1.wav', wav(a));
    final before = File(good.path).readAsBytesSync();
    expect(
      SegmentJoiner.join([
        good,
        DraftSegment(path: '${dir.path}/gone.wav', durationMs: 2000),
        seg('3.wav', wav(b)),
      ], '${dir.path}/out.wav'),
      throwsA(isA<FileSystemException>()),
    );
    expect(File('${dir.path}/out.wav').existsSync(), isFalse);
    expect(File(good.path).readAsBytesSync(), before); // originals untouched
  });

  test('a recorded segment with no audio fails', () async {
    expect(
      SegmentJoiner.join([
        seg('1.wav', wav(a)),
        seg('empty.wav', wav(const [])).copyWith(durationMs: 1500),
      ], '${dir.path}/out.wav'),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('a segment of another format fails, never mixed in', () async {
    expect(
      SegmentJoiner.join([
        seg('1.wav', wav(a)),
        seg('o.wav', wav(b, sampleRate: 16000)).copyWith(durationMs: 1000),
      ], '${dir.path}/out.wav'),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('nothing playable throws', () async {
    expect(
      SegmentJoiner.join([
        seg('e.wav', wav(const [])).copyWith(durationMs: 0, closed: false),
      ], '${dir.path}/o.wav'),
      throwsA(isA<FileSystemException>()),
    );
  });
}
