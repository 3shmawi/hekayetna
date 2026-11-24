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
  Future<FamilySpace?> getMySpace() async {
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

  @override
  Future<FamilySpace> createSpace(String name) async {
    final row = await _client
        .from('family_spaces')
        .insert({'name': name, 'created_by': _uid})
        .select()
        .single();
    final space = FamilySpace.fromJson(row);
    await _client.from('family_memberships').insert({
      'space_id': space.id,
      'user_id': _uid,
      'role': 'owner',
    });
    return space;
  }

  @override
  Future<FamilySpace> joinSpace(String inviteCode) async {
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

  @override
  Future<List<FamilyMember>> listMembers(String spaceId) async {
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

  @override
  Future<void> removeMember(String membershipId) async {
    // RPC, not a raw delete: it records a rejoin block so the removed member
    // cannot come back on the unchanged invite code (migration 0004).
    await _client.rpc<String>(
      'remove_family_member',
      params: {'p_membership_id': membershipId},
    );
  }

  @override
  Future<List<Person>> listPersons(String spaceId) async {
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

  @override
  Future<Person> createPerson(Person person) async {
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

  @override
  Future<Person> updatePerson(Person person) async {
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

  @override
  Future<List<Relationship>> listRelationships(String spaceId) async {
    final rows = await _client
        .from('relationships')
        .select()
        .eq('space_id', spaceId);
    return [
      for (final r in (rows as List).cast<Map<String, dynamic>>())
        Relationship.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  @override
  Future<Relationship> addRelationship({
    required String personId,
    required String relatedPersonId,
    required RelationshipType type,
  }) async {
    final space = await getMySpace();
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

  @override
  Future<void> confirmRelationship(String relationshipId) async {
    await _client
        .from('relationships')
        .update({'status': 'confirmed'})
        .eq('id', relationshipId);
  }
}
