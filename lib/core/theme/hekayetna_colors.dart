import 'package:flutter/material.dart';

/// The brand colors that have no `ColorScheme` role: the recording
/// terracotta, the gold accents, and the line/ink-soft/sand tokens in both
/// brightnesses. Read them with `context.hk` (app_theme.dart).
///
/// Values are the Design System `tokens.json` table, light and dark.
@immutable
class HekayetnaColors extends ThemeExtension<HekayetnaColors> {
  const HekayetnaColors({
    required this.record,
    required this.onRecord,
    required this.recordTint,
    required this.gold,
    required this.goldTint,
    required this.line,
    required this.inkSoft,
    required this.sand,
  });

  /// Terracotta: recording only, so it always means "your voice is being
  /// kept".
  final Color record;
  final Color onRecord;

  /// The record halo and draft badges.
  final Color recordTint;

  /// Small accents only; never text on light.
  final Color gold;

  /// The demo band and "sample" tags.
  final Color goldTint;

  /// Borders and dividers (also `colorScheme.outlineVariant`).
  final Color line;

  /// Secondary text (also `colorScheme.onSurfaceVariant`).
  final Color inkSoft;

  /// Scaffold background.
  final Color sand;

  static const light = HekayetnaColors(
    record: Color(0xFF9C4A21),
    onRecord: Color(0xFFFFFFFF),
    recordTint: Color(0xFFF3E1D6),
    gold: Color(0xFFC9A227),
    goldTint: Color(0xFFF5ECD0),
    line: Color(0xFFE2D9C8),
    inkSoft: Color(0xFF5A645C),
    sand: Color(0xFFF6F1E7),
  );

  static const dark = HekayetnaColors(
    record: Color(0xFFE08A5C),
    onRecord: Color(0xFF2A1408),
    recordTint: Color(0xFF3A2418),
    gold: Color(0xFFD9B84A),
    goldTint: Color(0xFF332B14),
    line: Color(0xFF3A342C),
    inkSoft: Color(0xFFB4BDB5),
    sand: Color(0xFF171512),
  );

  @override
  HekayetnaColors copyWith({
    Color? record,
    Color? onRecord,
    Color? recordTint,
    Color? gold,
    Color? goldTint,
    Color? line,
    Color? inkSoft,
    Color? sand,
  }) {
    return HekayetnaColors(
      record: record ?? this.record,
      onRecord: onRecord ?? this.onRecord,
      recordTint: recordTint ?? this.recordTint,
      gold: gold ?? this.gold,
      goldTint: goldTint ?? this.goldTint,
      line: line ?? this.line,
      inkSoft: inkSoft ?? this.inkSoft,
      sand: sand ?? this.sand,
    );
  }

  @override
  HekayetnaColors lerp(HekayetnaColors? other, double t) {
    if (other is! HekayetnaColors) return this;
    return HekayetnaColors(
      record: Color.lerp(record, other.record, t)!,
      onRecord: Color.lerp(onRecord, other.onRecord, t)!,
      recordTint: Color.lerp(recordTint, other.recordTint, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      goldTint: Color.lerp(goldTint, other.goldTint, t)!,
      line: Color.lerp(line, other.line, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      sand: Color.lerp(sand, other.sand, t)!,
    );
  }
}
