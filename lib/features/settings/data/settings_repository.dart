import 'package:family_stories/features/settings/data/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists [AppSettings] on the device.
class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _localeKey = 'settings.locale';
  static const _themeModeKey = 'settings.theme_mode';
  static const _narratorKey = 'settings.last_narrator_id';
  static const _promptsKey = 'settings.show_prompts';

  AppSettings load() {
    final languageCode = _prefs.getString(_localeKey);
    final themeModeName = _prefs.getString(_themeModeKey);
    return AppSettings(
      locale: languageCode == null ? null : Locale(languageCode),
      themeMode:
          ThemeMode.values.asNameMap()[themeModeName] ?? ThemeMode.system,
      lastNarratorId: _prefs.getString(_narratorKey),
      showPrompts: _prefs.getBool(_promptsKey) ?? true,
    );
  }

  Future<void> save(AppSettings settings) async {
    final locale = settings.locale;
    if (locale == null) {
      await _prefs.remove(_localeKey);
    } else {
      await _prefs.setString(_localeKey, locale.languageCode);
    }
    await _prefs.setString(_themeModeKey, settings.themeMode.name);
    final narrator = settings.lastNarratorId;
    if (narrator == null) {
      await _prefs.remove(_narratorKey);
    } else {
      await _prefs.setString(_narratorKey, narrator);
    }
    await _prefs.setBool(_promptsKey, settings.showPrompts);
  }
}
