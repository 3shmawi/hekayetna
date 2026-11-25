import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/family/domain/family_graph.dart';
import 'package:family_stories/features/family/domain/kinship.dart';
import 'package:family_stories/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'family_fixtures.dart';

void main() {
  final fam = bigFamily();
  final graph = FamilyGraph.build(
    persons: fam.persons,
    relationships: fam.rels,
    meId: 'me',
  );
  final en = lookupAppLocalizations(const Locale('en'));
  final ar = lookupAppLocalizations(const Locale('ar'));

  // target id, key, English, Arabic
  final table = <(String, String, String, String)>[
    ('me', 'me', 'You', 'أنت'),
    ('mama', 'mother', 'Mother', 'أم'),
    ('baba', 'father', 'Father', 'أب'),
    ('sitto', 'grandmother', 'Grandmother', 'جدة'),
    ('giddu', 'grandfather', 'Grandfather', 'جد'),
    ('gadda', 'grandmother', 'Grandmother', 'جدة'),
    ('gadd', 'grandfather', 'Grandfather', 'جد'),
    ('ggm', 'greatGrandmother', 'Great-grandmother', 'جدة الأب أو الأم'),
    ('khal', 'uncle_m', 'Uncle', 'خال'),
    ('khala', 'aunt_m', 'Aunt', 'خالة'),
    ('amm', 'uncle_p', 'Uncle', 'عم'),
    ('amma', 'aunt_p', 'Aunt', 'عمة'),
    ('khalSon', 'cousinSon_mm', 'Cousin', 'ابن خال'),
    ('khalaDaughter', 'cousinDaughter_mf', 'Cousin', 'بنت خالة'),
    ('ammDaughter', 'cousinDaughter_pm', 'Cousin', 'بنت عم'),
    ('ammaSon', 'cousinSon_pf', 'Cousin', 'ابن عمة'),
    ('sis', 'sister', 'Sister', 'أخت'),
    ('bro', 'brother', 'Brother', 'أخ'),
    ('sisSon', 'nephew_f', 'Nephew', 'ابن أخت'),
    ('broDaughter', 'niece_m', 'Niece', 'بنت أخ'),
    ('broWife', 'sisterInLaw', 'Sister-in-law', 'نسيبة'),
    ('wife', 'wife', 'Wife', 'زوجة'),
    ('mil', 'motherInLaw', 'Mother-in-law', 'حماة'),
    ('fil', 'fatherInLaw', 'Father-in-law', 'حما'),
    ('wifeSister', 'sisterInLaw', 'Sister-in-law', 'نسيبة'),
    ('wifeBrother', 'brotherInLaw', 'Brother-in-law', 'نسيب'),
    ('daughter', 'daughter', 'Daughter', 'بنت'),
    ('son', 'son', 'Son', 'ابن'),
    ('daughterHusband', 'sonInLaw', 'Son-in-law', 'زوج البنت'),
    ('sonWife', 'daughterInLaw', 'Daughter-in-law', 'زوجة الابن'),
    ('grandDaughter', 'granddaughter', 'Granddaughter', 'حفيدة'),
    ('grandSon', 'grandson', 'Grandson', 'حفيد'),
    (
      'greatGrandDaughter',
      'greatGranddaughter',
      'Great-granddaughter',
      'حفيدة الابن أو البنت',
    ),
    // Pending relationships are not used: the aunt is not confirmed yet.
    ('pendingAunt', 'notConfirmed', 'Not confirmed yet', 'لم يتأكد بعد'),
    ('stranger', 'relative', 'Relative', 'قريب'),
  ];

  for (final (id, key, e, a) in table) {
    test('$id is $key ($e / $a)', () {
      final got = kinshipKey(graph, 'me', id);
      expect(got, key);
      expect(en.kinshipLabel(got), e);
      expect(ar.kinshipLabel(got), a);
    });
  }

  group('unknown gender uses neutral forms', () {
    // x is the middle person; every other person has no gender recorded.
    FamilyGraph g(List<Relationship> r, List<String> ids) => FamilyGraph.build(
      persons: [for (final i in ids) person(i)],
      relationships: r,
    );
    final cases = <(String, FamilyGraph, String, String, String, String)>[
      (
        'parent',
        g([parentOf('p', 'me')], ['me', 'p']),
        'p',
        'parent',
        'Parent',
        'أب أو أم',
      ),
      (
        'grandparent',
        g([parentOf('p', 'me'), parentOf('gp', 'p')], ['me', 'p', 'gp']),
        'gp',
        'grandparent',
        'Grandparent',
        'جد أو جدة',
      ),
      (
        'sibling',
        g([siblings('me', 's')], ['me', 's']),
        's',
        'sibling',
        'Sibling',
        'أخ أو أخت',
      ),
      (
        'spouse',
        g([spouses('me', 's')], ['me', 's']),
        's',
        'spouse',
        'Spouse',
        'زوج أو زوجة',
      ),
      (
        'child',
        g([parentOf('me', 'c')], ['me', 'c']),
        'c',
        'child',
        'Child',
        'ابن أو بنت',
      ),
      (
        'aunt or uncle, side unknown',
        g(
          [parentOf('p', 'me'), parentOf('gp', 'p'), parentOf('gp', 'x')],
          ['me', 'p', 'gp', 'x'],
        ),
        'x',
        'auntOrUncle_x',
        'Aunt or uncle',
        'عم أو خال أو عمة أو خالة',
      ),
      (
        'cousin, side unknown',
        g(
          [
            parentOf('p', 'me'),
            parentOf('gp', 'p'),
            parentOf('gp', 'x'),
            parentOf('x', 'k'),
          ],
          ['me', 'p', 'gp', 'x', 'k'],
        ),
        'k',
        'cousinChild_x',
        'Cousin',
        'ابن أو بنت عم أو خال',
      ),
    ];
    for (final (name, graph, id, key, e, a) in cases) {
      test(name, () {
        final got = kinshipKey(graph, 'me', id);
        expect(got, key);
        expect(en.kinshipLabel(got), e);
        expect(ar.kinshipLabel(got), a);
      });
    }

    test('mother known, aunt gender unknown: maternal neutral', () {
      final graph = FamilyGraph.build(
        persons: [person('me'), person('mum', f), person('gm'), person('x')],
        relationships: [
          parentOf('mum', 'me'),
          parentOf('gm', 'mum'),
          parentOf('gm', 'x'),
        ],
      );
      expect(kinshipKey(graph, 'me', 'x'), 'auntOrUncle_m');
      expect(ar.kinshipLabel('auntOrUncle_m'), 'خال أو خالة');
    });
  });

  test('sibling through a shared parent needs no sibling row', () {
    final graph = FamilyGraph.build(
      persons: [person('me', m), person('s', f), person('p', f)],
      relationships: [parentOf('p', 'me'), parentOf('p', 's')],
    );
    expect(kinshipKey(graph, 'me', 's'), 'sister');
  });

  test('longer relations fall back to relative, never to a wrong word', () {
    final graph = FamilyGraph.build(
      persons: [
        for (final i in ['me', 'p', 'gp', 'ggp', 'gx', 'gk']) person(i),
      ],
      relationships: [
        parentOf('p', 'me'),
        parentOf('gp', 'p'),
        parentOf('ggp', 'gp'),
        parentOf('ggp', 'gx'),
        parentOf('gx', 'gk'),
      ],
    );
    expect(kinshipKey(graph, 'me', 'gk'), 'relative');
  });

  test('great-great-grandmother is still a great-grandmother', () {
    final graph = FamilyGraph.build(
      persons: [
        person('me'),
        person('a'),
        person('b'),
        person('c'),
        person('d', f),
      ],
      relationships: [
        parentOf('a', 'me'),
        parentOf('b', 'a'),
        parentOf('c', 'b'),
        parentOf('d', 'c'),
      ],
    );
    expect(kinshipKey(graph, 'me', 'd'), 'greatGrandmother');
  });

  test('the key is stable when two equal-length paths exist', () {
    // Cousins through both parents' lines still give one answer.
    final a = kinshipKey(graph, 'me', 'khalSon');
    for (var i = 0; i < 5; i++) {
      expect(kinshipKey(graph, 'me', 'khalSon'), a);
    }
  });

  test('every key has words in both languages (no fallback word)', () {
    for (final key in kinshipKeys) {
      for (final l in [en, ar]) {
        final text = l.kinshipLabel(key);
        expect(text, isNotEmpty);
        if (key != 'relative') {
          expect(
            text,
            isNot(l.kinshipLabel('relative')),
            reason: '$key falls back to the generic word',
          );
        }
      }
    }
  });

  test('every key kinshipKey can return is in kinshipKeys', () {
    for (final p in fam.persons) {
      expect(kinshipKeys, contains(kinshipKey(graph, 'me', p.id)));
    }
  });

  test('pathBetween returns people and steps', () {
    final path = graph.pathBetween('me', 'khal')!;
    expect(path.people, ['me', 'mama', 'khal']);
    expect(path.steps, [KinStep.up, KinStep.sibling]);
  });
}
