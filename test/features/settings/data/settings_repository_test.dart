import 'package:family_stories/features/settings/data/app_settings.dart';
import 'package:family_stories/features/settings/data/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(SettingsRepository, () {
    Future<SettingsRepository> create([
      Map<String, Object> values = const {},
    ]) async {
      SharedPreferences.setMockInitialValues(values);
      return SettingsRepository(await SharedPreferences.getInstance());
    }

    test('returns defaults when nothing is stored', () async {
      final repository = await create();
      expect(repository.load(), const AppSettings());
    });

    test('saves and loads locale and theme mode', () async {
      final repository = await create();
      const settings = AppSettings(
        locale: Locale('ar'),
        themeMode: ThemeMode.dark,
      );

      await repository.save(settings);

      expect(repository.load(), settings);
    });

    test('remembers the last narrator and the prompts switch', () async {
      final repository = await create();
      expect(repository.load().lastNarratorId, isNull);
      expect(repository.load().showPrompts, isTrue);

      await repository.save(
        const AppSettings(lastNarratorId: 'p7', showPrompts: false),
      );
      expect(repository.load().lastNarratorId, 'p7');
      expect(repository.load().showPrompts, isFalse);

      await repository.save(const AppSettings());
      expect(repository.load().lastNarratorId, isNull);
    });

    test('clears the locale when following the device language', () async {
      final repository = await create({'settings.locale': 'ar'});

      await repository.save(const AppSettings());

      expect(repository.load().locale, isNull);
    });
  });
}
