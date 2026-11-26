import 'package:family_stories/core/network/app_failure.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/features/family/data/family_repository.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/family/domain/invite_code.dart';

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

  var _space = const FamilySpace(
    id: 'demo-space',
    name: 'Sample Family (demo)',
    inviteCode: '00000000-0000-4000-8000-000000000000',
    inviteShortCode: '7K4QM9X',
  );
  final List<Person> _persons = [];
  final List<Relationship> _relationships = [];
  var _seq = 0;

  @override
  Future<Result<FamilySpace?>> getMySpace() => guard(_getMySpace);

  @override
  Future<Result<FamilySpace>> createSpace(String name) =>
      guard(() => _createSpace(name));

  @override
  Future<Result<FamilySpace>> joinSpace(String inviteCode) =>
      guard(() => _joinSpace(inviteCode));

  @override
  Future<Result<FamilyPreview>> previewFamily(String inviteCode) =>
      guard(() async {
        _requireCode(inviteCode);
        return FamilyPreview(name: _space.name, memberCount: 1);
      });

  String _myName = '';

  @override
  Future<Result<String>> getMyDisplayName() => guard(() async => _myName);

  @override
  Future<Result<String>> setMyDisplayName(String name) => guard(() async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 40) {
      throw const FamilyException('invalid_display_name');
    }
    return _myName = trimmed;
  });

  @override
  Future<Result<String>> rotateInviteCode(String spaceId) => guard(() async {
    const alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
    final next = [
      for (var i = 0; i < 7; i++)
        alphabet[(_seq++ * 7 + i * 3) % alphabet.length],
    ].join();
    _space = _space.withShortCode(next);
    return next;
  });

  InviteCode _requireCode(String raw) {
    final code = InviteCode.parse(raw);
    if (code == null) {
      throw const FamilyFailure(FamilyFailureReason.invalidInviteCode);
    }
    return code;
  }

  @override
  Future<Result<List<FamilyMember>>> listMembers(String spaceId) =>
      guard(() => _listMembers(spaceId));

  @override
  Future<Result<void>> removeMember(String membershipId) =>
      guard(() => _removeMember(membershipId));

  @override
  Future<Result<List<Person>>> listPersons(String spaceId) =>
      guard(() => _listPersons(spaceId));

  @override
  Future<Result<Person>> createPerson(Person person) =>
      guard(() => _createPerson(person));

  @override
  Future<Result<Person>> updatePerson(Person person) =>
      guard(() => _updatePerson(person));

  @override
  Future<Result<List<Relationship>>> listRelationships(String spaceId) =>
      guard(() => _listRelationships(spaceId));

  @override
  Future<Result<Relationship>> addRelationship({
    required String personId,
    required String relatedPersonId,
    required RelationshipType type,
  }) => guard(
    () => _addRelationship(
      personId: personId,
      relatedPersonId: relatedPersonId,
      type: type,
    ),
  );

  @override
  Future<Result<void>> confirmRelationship(String relationshipId) =>
      guard(() => _confirmRelationship(relationshipId));

  Future<FamilySpace?> _getMySpace() async => _space;

  Future<FamilySpace> _createSpace(String name) async =>
      FamilySpace(id: 'demo-space', name: name, inviteCode: 'DEMO-1234');

  Future<FamilySpace> _joinSpace(String inviteCode) async {
    _requireCode(inviteCode);
    return _space;
  }

  Future<List<FamilyMember>> _listMembers(String spaceId) async => const [
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

  Future<void> _removeMember(String membershipId) async {}

  Future<List<Person>> _listPersons(String spaceId) async =>
      List.unmodifiable(_persons);

  Future<Person> _createPerson(Person person) async {
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

  Future<Person> _updatePerson(Person person) async {
    final i = _persons.indexWhere((p) => p.id == person.id);
    if (i < 0) throw const NotFoundFailure();
    _persons[i] = person;
    return person;
  }

  Future<List<Relationship>> _listRelationships(String spaceId) async =>
      List.unmodifiable(_relationships);

  Future<Relationship> _addRelationship({
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

  Future<void> _confirmRelationship(String relationshipId) async {
    final i = _relationships.indexWhere((r) => r.id == relationshipId);
    if (i < 0) throw const NotFoundFailure();
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
