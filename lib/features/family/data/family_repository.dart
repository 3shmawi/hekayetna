import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/features/family/data/models.dart';

abstract class FamilyRepository {
  Future<Result<FamilySpace?>> getMySpace();
  Future<Result<FamilySpace>> createSpace(String name);

  /// Joins with a short code or an old UUID code. Junk never reaches the
  /// backend: it is rejected as an invalid code first.
  Future<Result<FamilySpace>> joinSpace(String inviteCode);

  /// The family name and head count for a code, for the confirm screen.
  Future<Result<FamilyPreview>> previewFamily(String inviteCode);

  /// Owner only. Returns the new short code; the old codes stop working.
  Future<Result<String>> rotateInviteCode(String spaceId);
  Future<Result<List<FamilyMember>>> listMembers(String spaceId);

  /// Owner removes a member (or a member leaves). The revoke trigger deletes
  /// their story/photo grants in the same transaction; rejoining restores
  /// nothing.
  Future<Result<void>> removeMember(String membershipId);
  Future<Result<List<Person>>> listPersons(String spaceId);
  Future<Result<Person>> createPerson(Person person);
  Future<Result<Person>> updatePerson(Person person);
  Future<Result<List<Relationship>>> listRelationships(String spaceId);
  Future<Result<Relationship>> addRelationship({
    required String personId,
    required String relatedPersonId,
    required RelationshipType type,
  });
  Future<Result<void>> confirmRelationship(String relationshipId);
}

class FamilyException implements Exception {
  const FamilyException(this.message);
  final String message;
  @override
  String toString() => 'FamilyException: $message';
}
