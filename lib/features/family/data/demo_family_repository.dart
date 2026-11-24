import 'package:family_stories/features/family/data/family_repository.dart';
import 'package:family_stories/features/family/data/models.dart';

/// DEMO MODE ONLY. In-memory data with realistic sample content (an Egyptian
/// family) so screens can be reviewed honestly without a backend.
class DemoFamilyRepository implements FamilyRepository {
  DemoFamilyRepository() {
    _persons.addAll(const [
      Person(
        id: 'p-sitto',
        spaceId: 'demo-space',
        fullName: 'Sitto Amina (sample)',
        approxBirthDate: 'about 1948',
        bio:
            'Sample person. Grew up in a Delta village, tells the best '
            'Ramadan stories.',
        createdBy: 'demo-user',
      ),
      Person(
        id: 'p-giddu',
        spaceId: 'demo-space',
        fullName: 'Giddu Mahmoud (sample)',
        approxBirthDate: 'about 1945',
        approxDeathDate: '2019',
        createdBy: 'demo-user',
      ),
      Person(
        id: 'p-mama',
        spaceId: 'demo-space',
        fullName: 'Mama (sample)',
        approxBirthDate: '1970',
        createdBy: 'demo-user',
      ),
      Person(
        id: 'p-me',
        spaceId: 'demo-space',
        fullName: 'Me (sample)',
        linkedUserId: 'demo-user',
        createdBy: 'demo-user',
      ),
    ]);
    _relationships.addAll(const [
      Relationship(
        id: 'r1',
        personId: 'p-sitto',
        relatedPersonId: 'p-giddu',
        type: RelationshipType.spouse,
        status: RelationshipStatus.confirmed,
      ),
      Relationship(
        id: 'r2',
        personId: 'p-sitto',
        relatedPersonId: 'p-mama',
        type: RelationshipType.parent,
        status: RelationshipStatus.confirmed,
      ),
      Relationship(
        id: 'r3',
        personId: 'p-mama',
        relatedPersonId: 'p-me',
        type: RelationshipType.parent,
        status: RelationshipStatus.pending,
      ),
    ]);
  }

  final _space = const FamilySpace(
    id: 'demo-space',
    name: 'Sample Family (demo)',
    inviteCode: 'DEMO-1234',
  );
  final List<Person> _persons = [];
  final List<Relationship> _relationships = [];
  var _seq = 0;

  @override
  Future<FamilySpace?> getMySpace() async => _space;

  @override
  Future<FamilySpace> createSpace(String name) async =>
      FamilySpace(id: 'demo-space', name: name, inviteCode: 'DEMO-1234');

  @override
  Future<FamilySpace> joinSpace(String inviteCode) async {
    if (inviteCode.trim().isEmpty) {
      throw const FamilyException('invalid_invite_code');
    }
    return _space;
  }

  @override
  Future<List<FamilyMember>> listMembers(String spaceId) async => const [
    FamilyMember(
      id: 'm1',
      userId: 'demo-user',
      displayName: 'Me',
      role: 'owner',
      personId: 'p-me',
    ),
    // Second member so the owner-only remove action is visible in review
    // builds. Clearly labeled sample.
    FamilyMember(
      id: 'm2',
      userId: 'demo-user-2',
      displayName: 'Uncle Sami (sample)',
      role: 'member',
    ),
  ];

  @override
  Future<void> removeMember(String membershipId) async {}

  @override
  Future<List<Person>> listPersons(String spaceId) async =>
      List.unmodifiable(_persons);

  @override
  Future<Person> createPerson(Person person) async {
    final p = Person(
      id: 'p-${_seq++}',
      spaceId: person.spaceId,
      fullName: person.fullName,
      photoPath: person.photoPath,
      approxBirthDate: person.approxBirthDate,
      approxDeathDate: person.approxDeathDate,
      bio: person.bio,
      createdBy: person.createdBy,
    );
    _persons.add(p);
    return p;
  }

  @override
  Future<Person> updatePerson(Person person) async {
    final i = _persons.indexWhere((p) => p.id == person.id);
    if (i < 0) throw const FamilyException('not_found');
    _persons[i] = person;
    return person;
  }

  @override
  Future<List<Relationship>> listRelationships(String spaceId) async =>
      List.unmodifiable(_relationships);

  @override
  Future<Relationship> addRelationship({
    required String personId,
    required String relatedPersonId,
    required RelationshipType type,
  }) async {
    final r = Relationship(
      id: 'r-${_seq++}',
      personId: personId,
      relatedPersonId: relatedPersonId,
      type: type,
      status: RelationshipStatus.pending, // never auto-confirmed
    );
    _relationships.add(r);
    return r;
  }

  @override
  Future<void> confirmRelationship(String relationshipId) async {
    final i = _relationships.indexWhere((r) => r.id == relationshipId);
    if (i < 0) throw const FamilyException('not_found');
    final r = _relationships[i];
    _relationships[i] = Relationship(
      id: r.id,
      personId: r.personId,
      relatedPersonId: r.relatedPersonId,
      type: r.type,
      status: RelationshipStatus.confirmed,
    );
  }
}
