import 'dart:convert';
import 'dart:io';

import 'package:family_stories/features/stories/domain/story_topics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the ARB files: every user-facing string exists in both English and
/// Egyptian Arabic, and no topic is left untranslated.
void main() {
  Map<String, dynamic> contentKeys(String path) {
    final json =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    return json..removeWhere((k, _) => k.startsWith('@'));
  }

  test('en and ar ARB files carry the same keys', () {
    final en = contentKeys('lib/l10n/app_en.arb');
    final ar = contentKeys('lib/l10n/app_ar.arb');
    final missingInAr = en.keys.toSet().difference(ar.keys.toSet());
    final missingInEn = ar.keys.toSet().difference(en.keys.toSet());
    expect(missingInAr, isEmpty, reason: 'missing Arabic: $missingInAr');
    expect(missingInEn, isEmpty, reason: 'missing English: $missingInEn');
  });

  test('no string is empty in either locale', () {
    for (final path in ['lib/l10n/app_en.arb', 'lib/l10n/app_ar.arb']) {
      final strings = contentKeys(path);
      final empty = strings.entries
          .where((e) => (e.value as String).trim().isEmpty)
          .map((e) => e.key)
          .toList();
      expect(empty, isEmpty, reason: '$path has empty values: $empty');
    }
  });

  test('every story topic has a label in both locales', () {
    final en = contentKeys('lib/l10n/app_en.arb');
    final ar = contentKeys('lib/l10n/app_ar.arb');
    for (final t in kStoryTopics) {
      expect(en.containsKey('topic_$t'), isTrue, reason: 'en topic_$t');
      expect(ar.containsKey('topic_$t'), isTrue, reason: 'ar topic_$t');
    }
  });

  test('privacy copy keeps its promises in both locales', () {
    final en = contentKeys('lib/l10n/app_en.arb');
    final ar = contentKeys('lib/l10n/app_ar.arb');
    // Family visibility is a snapshot: people joining later get nothing.
    expect(en['visFamilyDesc'], contains('join later'));
    expect(ar['visFamilyDesc'], contains('هيدخل بعد كده'));
    // Linking a photo to a story never shares it.
    expect(en['visPhotoPrivateDesc'], contains('never shares'));
    // Removal loses everything; rejoining restores nothing.
    expect(en['removeMemberBody'], contains('nothing comes back'));
  });
}
