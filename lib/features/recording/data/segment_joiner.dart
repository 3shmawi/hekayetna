import 'dart:io';
import 'dart:typed_data';

import 'package:family_stories/features/stories/data/models.dart';

/// Joins the WAV segments of a take into one playable file (spec 02, Upload).
/// PCM from every segment is concatenated and a single header is written, so
/// the result is one valid WAV whose size is the sum of the segments' audio
/// plus one 44-byte header.
abstract final class SegmentJoiner {
  static const _header = 44;
  static const contentType = 'audio/wav';
  static const extension = 'wav';

  /// Writes the joined take to [outPath] and returns it. Segments that do
  /// not exist or hold no audio are skipped. Throws a [FileSystemException]
  /// when nothing playable is left, so callers never upload an empty file.
  static Future<String> join(
    List<DraftSegment> segments,
    String outPath,
  ) async {
    final out = File(outPath);
    await out.parent.create(recursive: true);
    final tmp = File('$outPath.tmp');
    final sink = tmp.openWrite();
    var pcmBytes = 0;
    Uint8List? format;
    try {
      sink.add(Uint8List(_header)); // placeholder header, rewritten below
      for (final s in segments) {
        final file = File(s.path);
        if (!file.existsSync()) continue;
        final length = await file.length();
        if (length <= _header) continue;
        final raf = await file.open();
        try {
          format ??= await _readHeader(raf);
        } finally {
          await raf.close();
        }
        await sink.addStream(file.openRead(_header));
        pcmBytes += length - _header;
      }
    } finally {
      await sink.close();
    }
    if (pcmBytes == 0 || format == null) {
      if (tmp.existsSync()) await tmp.delete();
      throw FileSystemException('No audio to join', outPath);
    }
    final header = Uint8List.fromList(format);
    ByteData.sublistView(header)
      ..setUint32(4, 36 + pcmBytes, Endian.little)
      ..setUint32(40, pcmBytes, Endian.little);
    final raf = await tmp.open(mode: FileMode.append);
    try {
      await raf.setPosition(0);
      await raf.writeFrom(header);
    } finally {
      await raf.close();
    }
    await tmp.rename(outPath);
    return outPath;
  }

  static Future<Uint8List> _readHeader(RandomAccessFile raf) async {
    await raf.setPosition(0);
    final bytes = await raf.read(_header);
    return bytes;
  }
}
