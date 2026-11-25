import 'package:family_stories/features/family/data/models.dart';

Person person(String id, [PersonGender? gender, String? name]) => Person(
  id: id,
  spaceId: 's',
  fullName: name ?? id,
  createdBy: 'u',
  gender: gender,
);

const PersonGender f = PersonGender.female;
const PersonGender m = PersonGender.male;

var _n = 0;
Relationship _r(
  String a,
  String b,
  RelationshipType t, [
  RelationshipStatus s = RelationshipStatus.confirmed,
]) => Relationship(
  id: 'r${_n++}',
  personId: a,
  relatedPersonId: b,
  type: t,
  status: s,
);

/// [parent] is the parent of [child].
Relationship parentOf(
  String parent,
  String child, [
  RelationshipStatus s = RelationshipStatus.confirmed,
]) => _r(child, parent, RelationshipType.parent, s);

Relationship spouses(
  String a,
  String b, [
  RelationshipStatus s = RelationshipStatus.confirmed,
]) => _r(a, b, RelationshipType.spouse, s);

Relationship siblings(String a, String b) => _r(a, b, RelationshipType.sibling);

/// A family that exercises every branch of the kinship table. "me" is
/// male; his mother's side is the Sitto/Giddu line, his father's side the
/// Gadda/Gadd line.
({List<Person> persons, List<Relationship> rels}) bigFamily() {
  final persons = [
    person('me', m),
    person('mama', f),
    person('baba', m),
    person('sitto', f), // mother's mother
    person('giddu', m), // mother's father
    person('gadda', f), // father's mother
    person('gadd', m), // father's father
    person('ggm', f), // mother's mother's mother
    person('khal', m), // mother's brother
    person('khala', f), // mother's sister
    person('amm', m), // father's brother
    person('amma', f), // father's sister
    person('khalSon', m), // child of khal
    person('khalaDaughter', f),
    person('ammDaughter', f),
    person('ammaSon', m),
    person('sis', f),
    person('bro', m),
    person('sisSon', m), // sis's son: nephew through a sister
    person('broDaughter', f), // bro's daughter: niece through a brother
    person('broWife', f),
    person('wife', f),
    person('mil', f),
    person('fil', m),
    person('wifeSister', f),
    person('wifeBrother', m),
    person('daughter', f),
    person('son', m),
    person('daughterHusband', m),
    person('sonWife', f),
    person('grandDaughter', f), // son's daughter
    person('grandSon', m), // daughter's son
    person('greatGrandDaughter', f), // grandDaughter's daughter
    person('stranger', f),
    person('pendingAunt', f),
  ];
  final rels = [
    parentOf('mama', 'me'), parentOf('baba', 'me'),
    parentOf('sitto', 'mama'), parentOf('giddu', 'mama'),
    spouses('sitto', 'giddu'),
    parentOf('gadda', 'baba'), parentOf('gadd', 'baba'),
    parentOf('ggm', 'sitto'),
    parentOf('sitto', 'khal'), parentOf('sitto', 'khala'),
    parentOf('gadda', 'amm'), parentOf('gadda', 'amma'),
    parentOf('khal', 'khalSon'),
    parentOf('khala', 'khalaDaughter'),
    parentOf('amm', 'ammDaughter'),
    parentOf('amma', 'ammaSon'),
    parentOf('mama', 'sis'), parentOf('baba', 'sis'),
    parentOf('mama', 'bro'), parentOf('baba', 'bro'),
    parentOf('sis', 'sisSon'),
    parentOf('bro', 'broDaughter'),
    spouses('bro', 'broWife'),
    spouses('me', 'wife'),
    parentOf('mil', 'wife'), parentOf('fil', 'wife'),
    parentOf('mil', 'wifeSister'), parentOf('mil', 'wifeBrother'),
    parentOf('me', 'daughter'), parentOf('me', 'son'),
    spouses('daughter', 'daughterHusband'),
    spouses('son', 'sonWife'),
    parentOf('son', 'grandDaughter'),
    parentOf('daughter', 'grandSon'),
    parentOf('grandDaughter', 'greatGrandDaughter'),
    // A relationship that is not confirmed yet: never used for labels.
    parentOf('gadda', 'pendingAunt', RelationshipStatus.pending),
  ];
  return (persons: persons, rels: rels);
}
