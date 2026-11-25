import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/features/family/data/family_repository.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Live backend implementation. Requires the migrations in supabase/migrations
/// to be deployed; access rules are enforced by RLS, not by this client.
class SupabaseFamilyRepository implements FamilyRepository {
  SupabaseFamilyRepository(this._client);
  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  @override
  Future<Result<FamilySpace?>> getMySpace() => guard(_getMySpace);

  @override
  Future<Result<FamilySpace>> createSpace(String name) =>
      guard(() => _createSpace(name));

  @override
  Future<Result<FamilySpace>> joinSpace(String inviteCode) =>
      guard(() => _joinSpace(inviteCode));

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

  Future<FamilySpace?> _getMySpace() async {
    final rows = await _client
        .from('family_memberships')
        .select('family_spaces(id, name, invite_code)')
        .eq('user_id', _uid)
        .limit(1);
    if ((rows as List).isEmpty) return null;
    return FamilySpace.fromJson(
      Map<String, dynamic>.from(rows[0]['family_spaces'] as Map),
    );
  }

  Future<FamilySpace> _createSpace(String name) async {
    // One RPC creates the space and the caller's owner membership together:
    // RLS hides a space from anyone who isn't a member yet, and members
    // can't add themselves (migration 0007).
    final id = await _client.rpc<String>(
      'create_family_space',
      params: {'p_name': name},
    );
    final row = await _client
        .from('family_spaces')
        .select()
        .eq('id', id)
        .single();
    return FamilySpace.fromJson(row);
  }

  Future<FamilySpace> _joinSpace(String inviteCode) async {
    final id = await _client.rpc<String>(
      'join_family_space',
      params: {'p_invite_code': inviteCode},
    );
    final row = await _client
        .from('family_spaces')
        .select()
        .eq('id', id)
        .single();
    return FamilySpace.fromJson(row);
  }

  Future<List<FamilyMember>> _listMembers(String spaceId) async {
    final rows = await _client
        .from('family_memberships')
        .select('id, user_id, role, person_id, profiles(display_name)')
        .eq('space_id', spaceId);
    return [
      for (final r in (rows as List).cast<Map<String, dynamic>>())
        FamilyMember(
          id: r['id'] as String,
          userId: r['user_id'] as String,
          displayName:
              (r['profiles'] as Map?)?['display_name'] as String? ?? '',
          role: r['role'] as String,
          personId: r['person_id'] as String?,
        ),
    ];
  }

  Future<void> _removeMember(String membershipId) async {
    // RPC, not a raw delete: it records a rejoin block so the removed member
    // cannot come back on the unchanged invite code (migration 0004).
    await _client.rpc<String>(
      'remove_family_member',
      params: {'p_membership_id': membershipId},
    );
  }

  Future<List<Person>> _listPersons(String spaceId) async {
    final rows = await _client
        .from('persons')
        .select()
        .eq('space_id', spaceId)
        .order('full_name');
    return [
      for (final r in (rows as List).cast<Map<String, dynamic>>())
        Person.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  Future<Person> _createPerson(Person person) async {
    final row = await _client
        .from('persons')
        .insert({
          'space_id': person.spaceId,
          'full_name': person.fullName,
          'approx_birth_date': person.approxBirthDate,
          'approx_death_date': person.approxDeathDate,
          'bio': person.bio,
          'created_by': _uid,
        })
        .select()
        .single();
    return Person.fromJson(row);
  }

  Future<Person> _updatePerson(Person person) async {
    final row = await _client
        .from('persons')
        .update({
          'full_name': person.fullName,
          'approx_birth_date': person.approxBirthDate,
          'approx_death_date': person.approxDeathDate,
          'bio': person.bio,
        })
        .eq('id', person.id)
        .select()
        .single();
    return Person.fromJson(row);
  }

  Future<List<Relationship>> _listRelationships(String spaceId) async {
    final rows = await _client
        .from('relationships')
        .select()
        .eq('space_id', spaceId);
    return [
      for (final r in (rows as List).cast<Map<String, dynamic>>())
        Relationship.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  Future<Relationship> _addRelationship({
    required String personId,
    required String relatedPersonId,
    required RelationshipType type,
  }) async {
    final space = await _getMySpace();
    final row = await _client
        .from('relationships')
        .insert({
          'space_id': space!.id,
          'person_id': personId,
          'related_person_id': relatedPersonId,
          'type': type.name,
          'status': 'pending',
          'created_by': _uid,
        })
        .select()
        .single();
    return Relationship.fromJson(row);
  }

  Future<void> _confirmRelationship(String relationshipId) async {
    await _client
        .from('relationships')
        .update({'status': 'confirmed'})
        .eq('id', relationshipId);
  }
}
