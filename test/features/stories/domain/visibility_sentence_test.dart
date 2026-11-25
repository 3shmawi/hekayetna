import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/domain/visibility_sentence.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _line(
  String lang,
  StoryVisibility v, {
  List<String> names = const [],
  int family = 8,
}) => visibilitySentence(
  lookupAppLocalizations(Locale(lang)),
  visibility: v,
  selectedNames: names,
  familyCount: family,
);

void main() {
  group('English', () {
    test('only me', () {
      expect(_line('en', StoryVisibility.private), 'Only you can hear this');
    });
    test('selected people name everyone', () {
      expect(
        _line('en', StoryVisibility.selected, names: ['Mama', 'Omar', 'Nour']),
        '3 people can hear this: Mama, Omar, Nour',
      );
      expect(
        _line('en', StoryVisibility.selected, names: ['Mama']),
        '1 person can hear this: Mama',
      );
    });
    test('whole family counts people now', () {
      expect(
        _line('en', StoryVisibility.family),
        'Everyone in the family now (8 people)',
      );
      expect(
        _line('en', StoryVisibility.family, family: 1),
        'Everyone in the family now (1 person)',
      );
    });
  });

  group('Arabic plurals', () {
    test('one, two, few and many forms for selected people', () {
      String sel(int n) => _line(
        'ar',
        StoryVisibility.selected,
        names: [for (var i = 0; i < n; i++) 'س$i'],
      );
      expect(sel(1), startsWith('شخص واحد يقدر'));
      expect(sel(2), startsWith('شخصين يقدروا'));
      expect(sel(3), startsWith('3 أشخاص يقدروا'));
      expect(sel(10), startsWith('10 أشخاص يقدروا'));
      expect(sel(11), startsWith('11 شخص يقدروا'));
      expect(sel(2), contains('س0، س1'));
    });
    test('whole family forms', () {
      String fam(int n) => _line('ar', StoryVisibility.family, family: n);
      expect(fam(1), contains('شخص واحد'));
      expect(fam(2), contains('شخصين'));
      expect(fam(8), contains('8 أشخاص'));
      expect(fam(20), contains('20 شخص'));
    });
    test('only me', () {
      expect(_line('ar', StoryVisibility.private), 'إنت بس اللي تقدر تسمعها');
    });
  });
}
