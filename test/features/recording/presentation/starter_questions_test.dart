import 'package:family_stories/features/recording/presentation/record_page.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starter questions follow the locale and are never empty', () {
    final en = starterQuestions(lookupAppLocalizations(const Locale('en')));
    final ar = starterQuestions(lookupAppLocalizations(const Locale('ar')));
    expect(en, hasLength(4));
    expect(ar, hasLength(4));
    for (var i = 0; i < 4; i++) {
      expect(en[i], isNotEmpty);
      expect(ar[i], isNotEmpty);
      expect(ar[i], isNot(en[i]));
      // Arabic questions contain Arabic letters and no Latin ones.
      expect(RegExp('[\u0600-\u06FF]').hasMatch(ar[i]), isTrue);
      expect(RegExp('[A-Za-z]').hasMatch(ar[i]), isFalse);
    }
  });

  test('Different question cycles through the list and wraps', () {
    final q = starterQuestions(lookupAppLocalizations(const Locale('ar')));
    expect(q[4 % q.length], q.first);
    expect({for (var i = 0; i < 4; i++) q[i % q.length]}, hasLength(4));
  });
}
