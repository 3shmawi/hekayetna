import 'dart:io';
import 'dart:typed_data';

/// Where the audio sits in a WAV file and how it is encoded.
class WavLayout {
  const WavLayout({
    required this.channels,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.dataStart,
    required this.dataBytes,
  });

  final int channels;
  final int sampleRate;
  final int bitsPerSample;

  /// Byte offset of the first PCM byte.
  final int dataStart;

  /// PCM bytes (whole frames), measured from the real file length, not the
  /// header field (an unclosed file carries a placeholder).
  final int dataBytes;
}

/// Result of inspecting a WAV file: its playable length in milliseconds.
class WavInfo {
  const WavInfo({required this.durationMs, required this.repaired});

  final int durationMs;

  /// True when the header sizes did not match the file and were rewritten.
  final bool repaired;
}

/// Repairs the header of a WAV segment that a kill cut off. The recorder
/// writes the RIFF and data sizes when it closes the file, so an open
/// segment carries placeholder sizes. We recompute both from the real file
/// length and measure the duration from the PCM byte count.
abstract final class WavRepair {
  static const _headerMin = 44;

  /// How much of the file start is scanned for the `data` chunk. Core Audio
  /// (iOS) pads the header with a filler chunk, so the audio does not start
  /// at byte 44 there.
  static const _headScan = 65536;

  /// Where the PCM starts and its format, for joining segments. Returns null
  /// when the file is missing, is not a PCM WAV, or holds no audio. Does not
  /// modify the file.
  static Future<WavLayout?> layout(File file) async {
    if (!file.existsSync()) return null;
    final length = await file.length();
    if (length <= _headerMin) return null;
    final raf = await file.open();
    try {
      final head = await raf.read(length < _headScan ? length : _headScan);
      final fmt = _parse(head, length);
      if (fmt == null || fmt.dataBytes <= 0) return null;
      return WavLayout(
        channels: fmt.channels,
        sampleRate: fmt.sampleRate,
        bitsPerSample: fmt.bitsPerSample,
        dataStart: fmt.dataSizeOffset + 4,
        dataBytes: fmt.dataBytes,
      );
    } finally {
      await raf.close();
    }
  }

  /// Inspects [file], fixes its header in place when needed, and returns the
  /// measured length. Returns null when the file is missing or holds no
  /// audio (no valid header, or zero PCM bytes).
  static Future<WavInfo?> repair(File file) async {
    if (!file.existsSync()) return null;
    final length = await file.length();
    if (length <= _headerMin) return null;
    final raf = await file.open(mode: FileMode.append);
    try {
      await raf.setPosition(0);
      final head = await raf.read(length < _headScan ? length : _headScan);
      final fmt = _parse(head, length);
      if (fmt == null || fmt.dataBytes <= 0) return null;
      final riffSize = length - 8;
      final needsFix =
          fmt.riffSizeField != riffSize || fmt.dataSizeField != fmt.dataBytes;
      if (needsFix) {
        await raf.setPosition(4);
        await raf.writeFrom(_le32(riffSize));
        await raf.setPosition(fmt.dataSizeOffset);
        await raf.writeFrom(_le32(fmt.dataBytes));
        await raf.flush();
      }
      final frameBytes = fmt.channels * fmt.bitsPerSample ~/ 8;
      final bytesPerSecond = fmt.sampleRate * frameBytes;
      if (bytesPerSecond <= 0) return null;
      return WavInfo(
        durationMs: fmt.dataBytes * 1000 ~/ bytesPerSecond,
        repaired: needsFix,
      );
    } finally {
      await raf.close();
    }
  }

  static Uint8List _le32(int v) =>
      (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List();

  static _Fmt? _parse(Uint8List head, int fileLength) {
    if (head.length < _headerMin) return null;
    final d = ByteData.sublistView(head);
    String tag(int o) => String.fromCharCodes(head.sublist(o, o + 4));
    if (tag(0) != 'RIFF' || tag(8) != 'WAVE') return null;
    var offset = 12;
    int? channels;
    int? sampleRate;
    int? bits;
    while (offset + 8 <= head.length) {
      final id = tag(offset);
      final size = d.getUint32(offset + 4, Endian.little);
      if (id == 'fmt ' && offset + 24 <= head.length) {
        channels = d.getUint16(offset + 10, Endian.little);
        sampleRate = d.getUint32(offset + 12, Endian.little);
        bits = d.getUint16(offset + 22, Endian.little);
      } else if (id == 'data') {
        if (channels == null || sampleRate == null || bits == null) {
          return null;
        }
        final start = offset + 8;
        final actual = fileLength - start;
        // Keep whole frames only: drop a torn last sample.
        final frame = channels * bits ~/ 8;
        final dataBytes = frame > 0 ? actual - actual % frame : actual;
        return _Fmt(
          channels: channels,
          sampleRate: sampleRate,
          bitsPerSample: bits,
          dataBytes: dataBytes,
          dataSizeOffset: offset + 4,
          dataSizeField: size,
          riffSizeField: d.getUint32(4, Endian.little),
        );
      }
      offset += 8 + size + (size.isOdd ? 1 : 0);
    }
    return null;
  }
}

class _Fmt {
  const _Fmt({
    required this.channels,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.dataBytes,
    required this.dataSizeOffset,
    required this.dataSizeField,
    required this.riffSizeField,
  });

  final int channels;
  final int sampleRate;
  final int bitsPerSample;
  final int dataBytes;
  final int dataSizeOffset;
  final int dataSizeField;
  final int riffSizeField;
}
