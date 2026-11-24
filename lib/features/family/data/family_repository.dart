import 'package:family_stories/features/family/data/models.dart';

abstract class FamilyRepository {
  Future<FamilySpace?> getMySpace();
  Future<FamilySpace> createSpace(String name);
  Future<FamilySpace> joinSpace(String inviteCode);
  Future<List<FamilyMember>> listMembers(String spaceId);

  /// Owner removes a member (or a member leaves). The revoke trigger deletes
  /// their story/photo grants in the same transaction; rejoining restores
  /// nothing.
  Future<void> removeMember(String membershipId);
  Future<List<Person>> listPersons(String spaceId);
  Future<Person> createPerson(Person person);
  Future<Person> updatePerson(Person person);
  Future<List<Relationship>> listRelationships(String spaceId);
  Future<Relationship> addRelationship({
    required String personId,
    required String relatedPersonId,
    required RelationshipType type,
  });
  Future<void> confirmRelationship(String relationshipId);
}

class FamilyException implements Exception {
  const FamilyException(this.message);
  final String message;
  @override
  String toString() => 'FamilyException: $message';
}
