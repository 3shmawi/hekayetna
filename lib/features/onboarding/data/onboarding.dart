import 'dart:convert';

import 'package:family_stories/core/router/app_routes.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether this install has seen the welcome screens. Stored on the device.
abstract final class Onboarding {
  static const _key = 'onboarding.done';
  static const _draftKey = 'onboarding.draft';

  /// `true` until [load] reads the real value, so tests and screens that
  /// don't care never get redirected.
  static final ValueNotifier<bool> seen = ValueNotifier(true);

  /// The names entered on the welcome screens, waiting to become the first
  /// people of the family tree. `null` when there is nothing to seed (the
  /// user skipped, or the draft was already used or dismissed).
  static final ValueNotifier<OnboardingDraft?> draft = ValueNotifier(null);

  static SharedPreferences? _prefs;

  /// Reads the saved values (core/di/dependencies.dart).
  static void load(SharedPreferences prefs) {
    _prefs = prefs;
    seen.value = prefs.getBool(_key) ?? false;
    final raw = prefs.getString(_draftKey);
    draft.value = raw == null ? null : OnboardingDraft.fromJson(raw);
  }

  static Future<void> complete() async {
    seen.value = true;
    await _prefs?.setBool(_key, true);
  }

  /// Keeps the welcome-screen names for the Family tab, or drops an empty
  /// draft so the seed card never appears with nothing to add.
  static Future<void> saveDraft(OnboardingDraft value) async {
    if (value.isEmpty) {
      await clearDraft();
      return;
    }
    draft.value = value;
    await _prefs?.setString(_draftKey, value.toJson());
  }

  static Future<void> clearDraft() async {
    draft.value = null;
    await _prefs?.remove(_draftKey);
  }
}

/// The people the new user sketched on the welcome screens: themselves and,
/// optionally, their parents. The Family tab offers to add exactly these
/// names; nothing is created until the user confirms there.
class OnboardingDraft {
  const OnboardingDraft({this.name = '', this.father = '', this.mother = ''});

  factory OnboardingDraft.fromJson(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return OnboardingDraft(
      name: j['name'] as String? ?? '',
      father: j['father'] as String? ?? '',
      mother: j['mother'] as String? ?? '',
    );
  }

  final String name;
  final String father;
  final String mother;

  bool get isEmpty =>
      name.trim().isEmpty && father.trim().isEmpty && mother.trim().isEmpty;

  /// The names that were actually entered, in tree order (you, then parents).
  List<String> get names => [
    name,
    father,
    mother,
  ].map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  String toJson() => jsonEncode({
    'name': name,
    'father': father,
    'mother': mother,
  });
}

/// A new install opening the app normally (the home screen) sees the
/// welcome screens first. Deep links into other screens go straight there.
String? onboardingRedirect(Uri uri, {required bool seen}) {
  if (seen) return null;
  return uri.path == AppRoutes.home ? AppRoutes.welcome : null;
}
