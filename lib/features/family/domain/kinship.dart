import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/family/domain/family_graph.dart';

/// What the target is to [from] ("what is she to me?"), as a **key** that the
/// `kinshipLabel` ARB message turns into words in each language. Pure Dart
/// so the table can be tested path by path.
///
/// Rules:
/// - Only confirmed relationships are used (the graph already drops pending
///   ones). No confirmed path but a pending relationship: `notConfirmed`.
///   No path at all: `relative`.
/// - Unknown gender picks a neutral key (`parent`, `sibling`, ...).
/// - Arabic distinguishes sides, so keys carry them: a mother's brother is
///   `uncle_m` (خال) and a father's brother `uncle_p` (عم). When the
///   connecting parent's gender is unknown the side is `x`.
/// - Great-aunts, step relations and anything longer fall back to `relative`.
String kinshipKey(FamilyGraph g, String from, String to) {
  if (from == to) return 'me';
  final path = g.pathBetween(from, to);
  if (path == null) {
    final hasPending = g.pending.any((e) => e.a == to || e.b == to);
    return hasPending ? 'notConfirmed' : 'relative';
  }
  final steps = path.steps;
  final code = steps
      .map(
        (s) => switch (s) {
          KinStep.up => 'u',
          KinStep.down => 'd',
          KinStep.spouse => 's',
          KinStep.sibling => 'b',
        },
      )
      .join();
  PersonGender? gender(int i) => g.persons[path.people[i]]?.gender;
  String pick(PersonGender? gen, String f, String m, String n) => switch (gen) {
    PersonGender.female => f,
    PersonGender.male => m,
    null => n,
  };
  String side(PersonGender? parent) =>
      pick(parent, 'm', 'p', 'x'); // maternal, paternal, unknown
  String gcode(PersonGender? x) => pick(x, 'f', 'm', 'x');

  final target = gender(path.people.length - 1);

  if (RegExp(r'^u{3,}$').hasMatch(code)) {
    return pick(
      target,
      'greatGrandmother',
      'greatGrandfather',
      'greatGrandparent',
    );
  }
  if (RegExp(r'^d{3,}$').hasMatch(code)) {
    return pick(
      target,
      'greatGranddaughter',
      'greatGrandson',
      'greatGrandchild',
    );
  }
  switch (code) {
    case 'u':
      return pick(target, 'mother', 'father', 'parent');
    case 'uu':
      return pick(target, 'grandmother', 'grandfather', 'grandparent');
    case 'd':
      return pick(target, 'daughter', 'son', 'child');
    case 'dd':
      return pick(target, 'granddaughter', 'grandson', 'grandchild');
    case 'b':
      return pick(target, 'sister', 'brother', 'sibling');
    case 's':
      return pick(target, 'wife', 'husband', 'spouse');
    case 'ub':
      final sd = side(gender(1));
      return '${pick(target, 'aunt', 'uncle', 'auntOrUncle')}_$sd';
    case 'ubd':
      final sd = side(gender(1));
      final base = pick(target, 'cousinDaughter', 'cousinSon', 'cousinChild');
      return sd == 'x' ? '${base}_x' : '${base}_$sd${gcode(gender(2))}';
    case 'bd':
      final base = pick(target, 'niece', 'nephew', 'nieceOrNephew');
      return '${base}_${gcode(gender(1))}';
    case 'su':
      return pick(target, 'motherInLaw', 'fatherInLaw', 'parentInLaw');
    case 'sb':
    case 'bs':
      return pick(target, 'sisterInLaw', 'brotherInLaw', 'siblingInLaw');
    case 'ds':
      return pick(target, 'daughterInLaw', 'sonInLaw', 'childInLaw');
  }
  return 'relative';
}

/// Every key [kinshipKey] can return. The ARB `kinshipLabel` select must
/// have a case for each one in both languages (checked by a test).
final List<String> kinshipKeys = _allKeys();

List<String> _allKeys() {
  const sides = ['m', 'p', 'x'];
  const g3 = ['f', 'm', 'x'];
  return [
    'me',
    'relative',
    'notConfirmed',
    for (final k in [
      'mother',
      'father',
      'parent',
      'grandmother',
      'grandfather',
      'grandparent',
      'greatGrandmother',
      'greatGrandfather',
      'greatGrandparent',
      'daughter',
      'son',
      'child',
      'granddaughter',
      'grandson',
      'grandchild',
      'greatGranddaughter',
      'greatGrandson',
      'greatGrandchild',
      'sister',
      'brother',
      'sibling',
      'wife',
      'husband',
      'spouse',
      'motherInLaw',
      'fatherInLaw',
      'parentInLaw',
      'sisterInLaw',
      'brotherInLaw',
      'siblingInLaw',
      'daughterInLaw',
      'sonInLaw',
      'childInLaw',
    ])
      k,
    for (final k in ['aunt', 'uncle', 'auntOrUncle'])
      for (final s in sides) '${k}_$s',
    for (final k in ['cousinDaughter', 'cousinSon', 'cousinChild']) ...[
      '${k}_x',
      for (final s in ['m', 'p'])
        for (final a in g3) '${k}_$s$a',
    ],
    for (final k in ['niece', 'nephew', 'nieceOrNephew'])
      for (final a in g3) '${k}_$a',
  ];
}
