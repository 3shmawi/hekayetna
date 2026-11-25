import 'dart:io';
import 'dart:typed_data';

import 'package:family_stories/features/recording/data/wav_repair.dart';
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
    WavLayout? format;
    try {
      sink.add(Uint8List(_header)); // placeholder header, rewritten below
      for (final s in segments) {
        final file = File(s.path);
        // The audio starts after whatever header the platform wrote (44 bytes
        // on Android, longer on iOS where Core Audio adds a filler chunk), so
        // the layout is read from the chunks, never assumed.
        final layout = await WavRepair.layout(file);
        // A segment that was recorded (it has a measured length or was
        // closed) must be in the take. Dropping it would publish a shortened
        // story as if it were complete, so that is an error and the draft is
        // left untouched. Only the trailing placeholder segment opened after
        // a pause (length 0, never closed) may legitimately hold no audio.
        final recorded = s.durationMs > 0 || s.closed;
        if (layout == null) {
          if (recorded) {
            throw FileSystemException(
              'A recorded segment is missing or unreadable',
              s.path,
            );
          }
          continue;
        }
        if (format == null) {
          format = layout;
        } else if (layout.channels != format.channels ||
            layout.sampleRate != format.sampleRate ||
            layout.bitsPerSample != format.bitsPerSample) {
          throw FileSystemException(
            'Segments have different audio formats',
            s.path,
          );
        }
        await sink.addStream(
          file.openRead(layout.dataStart, layout.dataStart + layout.dataBytes),
        );
        pcmBytes += layout.dataBytes;
      }
    } finally {
      await sink.close();
    }
    final fmt = format;
    if (pcmBytes == 0 || fmt == null) {
      if (tmp.existsSync()) await tmp.delete();
      throw FileSystemException('No audio to join', outPath);
    }
    final blockAlign = fmt.channels * fmt.bitsPerSample ~/ 8;
    final header = ByteData(_header);
    void tag(int offset, String text) {
      for (var i = 0; i < 4; i++) {
        header.setUint8(offset + i, text.codeUnitAt(i));
      }
    }

    tag(0, 'RIFF');
    header.setUint32(4, 36 + pcmBytes, Endian.little);
    tag(8, 'WAVE');
    tag(12, 'fmt ');
    header
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little) // PCM
      ..setUint16(22, fmt.channels, Endian.little)
      ..setUint32(24, fmt.sampleRate, Endian.little)
      ..setUint32(28, fmt.sampleRate * blockAlign, Endian.little)
      ..setUint16(32, blockAlign, Endian.little)
      ..setUint16(34, fmt.bitsPerSample, Endian.little);
    tag(36, 'data');
    header.setUint32(40, pcmBytes, Endian.little);
    final raf = await tmp.open(mode: FileMode.append);
    try {
      await raf.setPosition(0);
      await raf.writeFrom(header.buffer.asUint8List());
    } finally {
      await raf.close();
    }
    await tmp.rename(outPath);
    return outPath;
  }
}
