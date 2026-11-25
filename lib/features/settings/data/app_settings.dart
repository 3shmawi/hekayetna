import 'package:flutter/material.dart';

/// The user's app-wide preferences.
@immutable
class AppSettings {
  const AppSettings({
    this.locale,
    this.themeMode = ThemeMode.system,
    this.lastNarratorId,
    this.showPrompts = true,
  });

  /// `null` means "follow the device language".
  final Locale? locale;
  final ThemeMode themeMode;

  /// The person who narrated the last recording; the Record screen starts
  /// with them (spec 04).
  final String? lastNarratorId;

  /// Whether the Record screen shows the "Ask her / him" question card.
  final bool showPrompts;

  AppSettings copyWith({
    ValueGetter<Locale?>? locale,
    ThemeMode? themeMode,
    ValueGetter<String?>? lastNarratorId,
    bool? showPrompts,
  }) {
    return AppSettings(
      locale: locale != null ? locale() : this.locale,
      themeMode: themeMode ?? this.themeMode,
      lastNarratorId: lastNarratorId != null
          ? lastNarratorId()
          : this.lastNarratorId,
      showPrompts: showPrompts ?? this.showPrompts,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          other.locale == locale &&
          other.themeMode == themeMode &&
          other.lastNarratorId == lastNarratorId &&
          other.showPrompts == showPrompts;

  @override
  int get hashCode =>
      Object.hash(locale, themeMode, lastNarratorId, showPrompts);
}
