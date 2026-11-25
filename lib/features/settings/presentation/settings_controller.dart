import 'dart:async';

import 'package:family_stories/core/di/dependencies.dart';
import 'package:family_stories/features/settings/data/app_settings.dart';
import 'package:family_stories/features/settings/data/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Override in tests: `settingsRepositoryProvider.overrideWithValue(fake)`.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => Dependencies.settingsRepository,
);

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

/// Holds the current [AppSettings]; changes are applied immediately and
/// persisted in the background.
class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(settingsRepositoryProvider).load();

  void setLocale(Locale? locale) =>
      _update(state.copyWith(locale: () => locale));

  void setThemeMode(ThemeMode themeMode) =>
      _update(state.copyWith(themeMode: themeMode));

  void setLastNarrator(String? personId) =>
      _update(state.copyWith(lastNarratorId: () => personId));

  void setShowPrompts({required bool value}) =>
      _update(state.copyWith(showPrompts: value));

  void _update(AppSettings next) {
    if (next == state) return;
    state = next;
    unawaited(ref.read(settingsRepositoryProvider).save(next));
  }
}
