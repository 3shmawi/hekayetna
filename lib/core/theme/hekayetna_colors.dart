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
    required this.fill,
    required this.onFill,
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

  /// Primary button fill and its label color (dark mode keeps
  /// `colorScheme.primary` light for text and icons).
  final Color fill;
  final Color onFill;

  static const light = HekayetnaColors(
    record: Color(0xFF9C4A21),
    onRecord: Color(0xFFFFFFFF),
    recordTint: Color(0xFFF3E1D6),
    gold: Color(0xFFC9A227),
    goldTint: Color(0xFFF5ECD0),
    line: Color(0xFFDFE4DD),
    inkSoft: Color(0xFF4F564F),
    sand: Color(0xFFF6FBF4),
    fill: Color(0xFF243828),
    onFill: Color(0xFFFFFFFF),
  );

  static const dark = HekayetnaColors(
    record: Color(0xFFE08A5C),
    onRecord: Color(0xFF2A1408),
    recordTint: Color(0xFF3A2418),
    gold: Color(0xFFD9B84A),
    goldTint: Color(0xFF332B14),
    line: Color(0xFF27372C),
    inkSoft: Color(0xFF9EACA1),
    sand: Color(0xFF111A13),
    fill: Color(0xFF2F4A35),
    onFill: Color(0xFFF3F7F2),
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
    Color? fill,
    Color? onFill,
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
      fill: fill ?? this.fill,
      onFill: onFill ?? this.onFill,
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
      fill: Color.lerp(fill, other.fill, t)!,
      onFill: Color.lerp(onFill, other.onFill, t)!,
    );
  }
}
