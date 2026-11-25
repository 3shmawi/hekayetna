import 'dart:io';
import 'dart:typed_data';

import 'package:family_stories/features/recording/data/draft_recovery.dart';
import 'package:family_stories/features/recording/data/file_draft_store.dart';
import 'package:family_stories/features/recording/data/segment_joiner.dart';
import 'package:family_stories/features/recording/data/wav_repair.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a mono 16-bit 44.1 kHz WAV of [ms] milliseconds. [cut] simulates a
/// kill: the header still holds the placeholder sizes the recorder writes
/// before the file is closed.
Uint8List wav(int ms, {bool cut = false, int extraBytes = 0}) {
  final pcm = 44100 * 2 * ms ~/ 1000 + extraBytes;
  final b = ByteData(44 + pcm);
  void tag(int o, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, cut ? 0 : 36 + pcm, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, 44100, Endian.little)
    ..setUint32(28, 88200, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  tag(36, 'data');
  b.setUint32(40, cut ? 0 : pcm, Endian.little);
  return b.buffer.asUint8List();
}

void main() {
  late Directory dir;
  late FileDraftStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('recovery_test');
    store = FileDraftStore(directoryPath: dir.path);
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  Future<String> segment(String name, Uint8List bytes) async {
    final f = File('${dir.path}/$name.wav');
    await f.writeAsBytes(bytes);
    return f.path;
  }

  StoryDraft draft(List<DraftSegment> segs, DraftStatus status) => StoryDraft(
    id: 'd1',
    segments: segs,
    status: status,
    updatedAt: DateTime(2026, 11, 24),
  );

  test('WavRepair fixes a cut-off header and measures duration', () async {
    final path = await segment('cut', wav(2000, cut: true));
    final info = await WavRepair.repair(File(path));
    expect(info!.repaired, isTrue);
    expect(info.durationMs, 2000);
    final again = await WavRepair.repair(File(path));
    expect(again!.repaired, isFalse);
    expect(again.durationMs, 2000);
  });

  test('WavRepair drops a torn last sample', () async {
    final path = await segment('torn', wav(1000, cut: true, extraBytes: 1));
    final info = await WavRepair.repair(File(path));
    expect(info!.durationMs, 1000);
  });

  test('WavRepair returns null for missing, empty and non-wav files', () async {
    expect(await WavRepair.repair(File('${dir.path}/none.wav')), isNull);
    final header = await segment('empty', wav(0, cut: true));
    expect(await WavRepair.repair(File(header)), isNull);
    final junk = await segment('junk', Uint8List(200));
    expect(await WavRepair.repair(File(junk)), isNull);
  });

  test('AC-3: killed recording comes back interrupted, truncated segment '
      'kept and re-measured', () async {
    final closed = await segment('a', wav(30000));
    final cut = await segment('b', wav(4000, cut: true));
    await store.save(
      draft([
        DraftSegment(path: closed, durationMs: 30000, closed: true),
        DraftSegment(path: cut, durationMs: 1000),
      ], DraftStatus.recording),
    );
    final recovered = await DraftRecovery(
      store,
      now: () => DateTime(2026, 11, 25),
    ).run();
    expect(recovered, hasLength(1));
    final d = (await store.get('d1'))!;
    expect(d.status, DraftStatus.interrupted);
    expect(d.segments.map((s) => s.durationMs), [30000, 4000]);
    expect(d.segments.every((s) => s.closed), isTrue);
    expect(d.duration, const Duration(seconds: 34));
  });

  test('zero-length last segment is dropped, earlier audio is kept', () async {
    final good = await segment('a', wav(5000));
    final empty = await segment('b', wav(0, cut: true));
    await store.save(
      draft([
        DraftSegment(path: good, durationMs: 5000, closed: true),
        DraftSegment(path: empty, durationMs: 0),
      ], DraftStatus.paused),
    );
    await DraftRecovery(store).run();
    final d = (await store.get('d1'))!;
    expect(d.status, DraftStatus.interrupted);
    expect(d.segments, hasLength(1));
  });

  test('a draft with no audible audio is removed', () async {
    await store.save(
      draft([
        DraftSegment(path: '${dir.path}/gone.wav', durationMs: 0),
      ], DraftStatus.recording),
    );
    expect(await DraftRecovery(store).run(), isEmpty);
    expect(await store.list(), isEmpty);
  });

  test('finished and interrupted drafts are left untouched', () async {
    final p = await segment('a', wav(1000));
    await store.save(
      draft([
        DraftSegment(path: p, durationMs: 1000, closed: true),
      ], DraftStatus.finished),
    );
    expect(await DraftRecovery(store).run(), isEmpty);
    expect((await store.get('d1'))!.status, DraftStatus.finished);
  });

  test('AC-8: joiner writes one valid WAV, size = sum of segment audio + '
      'one header', () async {
    final a = await segment('a', wav(3000));
    final b = await segment('b', wav(2000));
    final gone = '${dir.path}/gone.wav';
    final out = await SegmentJoiner.join([
      DraftSegment(path: a, durationMs: 3000, closed: true),
      DraftSegment(path: gone, durationMs: 0),
      DraftSegment(path: b, durationMs: 2000, closed: true),
    ], '${dir.path}/d1/story.wav');
    final bytes = File(out).lengthSync();
    expect(bytes, File(a).lengthSync() + File(b).lengthSync() - 44);
    final info = await WavRepair.repair(File(out));
    expect(info!.repaired, isFalse); // header already correct
    expect(info.durationMs, 5000);
    expect(File('$out.tmp').existsSync(), isFalse);
  });

  test('joiner refuses to produce an empty file', () async {
    final empty = await segment('e', wav(0, cut: true));
    await expectLater(
      SegmentJoiner.join([
        DraftSegment(path: empty, durationMs: 0),
      ], '${dir.path}/story.wav'),
      throwsA(isA<FileSystemException>()),
    );
    expect(File('${dir.path}/story.wav').existsSync(), isFalse);
  });
}
