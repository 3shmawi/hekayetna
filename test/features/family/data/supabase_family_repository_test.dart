import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/features/family/data/family_repository.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/family/data/supabase_family_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/fake_postgrest.dart';

class _MockClient extends Mock implements SupabaseClient {}

class _MockAuth extends Mock implements GoTrueClient {}

const _boom = PostgrestException(message: 'denied', code: '42501');

Map<String, dynamic> _space() => {
  'id': 'sp',
  'name': 'The Family',
  'invite_code': 'abc',
};

Map<String, dynamic> _person({String id = 'p1'}) => {
  'id': id,
  'space_id': 'sp',
  'full_name': 'Sitto Amina',
  'created_by': 'u1',
};

Map<String, dynamic> _relationship() => {
  'id': 'r1',
  'person_id': 'p1',
  'related_person_id': 'p2',
  'type': 'parent',
  'status': 'pending',
};

const _newPerson = Person(
  id: 'p1',
  spaceId: 'sp',
  fullName: 'Sitto Amina',
  createdBy: 'u1',
  bio: 'Baked every Friday',
);

void main() {
  late FakeWorld world;
  late FamilyRepository repo;

  setUp(() {
    world = FakeWorld();
    final client = _MockClient();
    final auth = _MockAuth();
    when(() => client.from(any())).thenAnswer(
      (i) => FakeTable(i.positionalArguments.first as String, world),
    );
    when(() => client.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(
      const User(
        id: 'u1',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
      ),
    );
    stubRpc(client, world);
    repo = SupabaseFamilyRepository(client);
  });

  group('getMySpace', () {
    test('returns the space the user belongs to', () async {
      world.responses['family_memberships.select'] = [
        {'family_spaces': _space()},
      ];
      final r = await repo.getMySpace();
      expect((r as Success<FamilySpace?>).value?.name, 'The Family');
      expect(
        world.on('family_memberships', 'select').single.chain.first,
        'eq(user_id,u1)',
      );
    });
    test('no membership is Success(null)', () async {
      world.responses['family_memberships.select'] = <Map<String, dynamic>>[];
      expect((await repo.getMySpace() as Success<FamilySpace?>).value, isNull);
    });
    test('a backend error becomes Failed', () async {
      world.responses['family_memberships.select'] = _boom;
      expect(await repo.getMySpace(), isA<Failed<FamilySpace?>>());
    });
  });

  group('createSpace', () {
    test('calls the create RPC, then reads the space back', () async {
      world.responses['rpc:create_family_space.rpc'] = 'sp';
      world.responses['family_spaces.select'] = _space();
      final r = await repo.createSpace('The Family');
      expect((r as Success<FamilySpace>).value.id, 'sp');
      expect(world.on('rpc:create_family_space', 'rpc').single.args.single, {
        'p_name': 'The Family',
      });
    });
    test('an RPC error becomes Failed and nothing is read', () async {
      world.responses['rpc:create_family_space.rpc'] = _boom;
      expect(await repo.createSpace('x'), isA<Failed<FamilySpace>>());
      expect(world.on('family_spaces', 'select'), isEmpty);
    });
  });

  group('joinSpace', () {
    test('calls the join RPC with the invite code', () async {
      world.responses['rpc:join_family_space.rpc'] = 'sp';
      world.responses['family_spaces.select'] = _space();
      final r = await repo.joinSpace('abc');
      expect(r, isA<Success<FamilySpace>>());
      expect(world.on('rpc:join_family_space', 'rpc').single.args.single, {
        'p_invite_code': 'abc',
      });
    });
    test('a bad code or removed member becomes Failed', () async {
      world.responses['rpc:join_family_space.rpc'] = _boom;
      expect(await repo.joinSpace('nope'), isA<Failed<FamilySpace>>());
    });
  });

  group('listMembers', () {
    test('maps memberships with display names', () async {
      world.responses['family_memberships.select'] = [
        {
          'id': 'm1',
          'user_id': 'u1',
          'role': 'owner',
          'person_id': null,
          'profiles': {'display_name': 'Mona'},
        },
        {
          'id': 'm2',
          'user_id': 'u2',
          'role': 'member',
          'person_id': 'p1',
          'profiles': null,
        },
      ];
      final r = await repo.listMembers('sp');
      final members = (r as Success<List<FamilyMember>>).value;
      expect(members.map((m) => m.displayName), ['Mona', '']);
      expect(members.last.personId, 'p1');
    });
    test('a backend error becomes Failed', () async {
      world.responses['family_memberships.select'] = _boom;
      expect(await repo.listMembers('sp'), isA<Failed<List<FamilyMember>>>());
    });
  });

  group('removeMember', () {
    test('uses the RPC that records the rejoin block', () async {
      world.responses['rpc:remove_family_member.rpc'] = 'm2';
      expect(await repo.removeMember('m2'), isA<Success<void>>());
      expect(world.on('rpc:remove_family_member', 'rpc').single.args.single, {
        'p_membership_id': 'm2',
      });
      expect(world.on('family_memberships', 'delete'), isEmpty);
    });
    test('a backend error becomes Failed', () async {
      world.responses['rpc:remove_family_member.rpc'] = _boom;
      expect(await repo.removeMember('m2'), isA<Failed<void>>());
    });
  });

  group('persons', () {
    test('listPersons asks for the space sorted by name', () async {
      world.responses['persons.select'] = [_person(), _person(id: 'p2')];
      final r = await repo.listPersons('sp');
      expect((r as Success<List<Person>>).value, hasLength(2));
      final chain = world.on('persons', 'select').single.chain;
      expect(chain.first, 'eq(space_id,sp)');
      expect(chain.last, startsWith('order(full_name'));
    });
    test('listPersons failure', () async {
      world.responses['persons.select'] = _boom;
      expect(await repo.listPersons('sp'), isA<Failed<List<Person>>>());
    });

    test('createPerson inserts the fields and the creator', () async {
      world.responses['persons.insert'] = _person();
      final r = await repo.createPerson(_newPerson);
      expect(r, isA<Success<Person>>());
      final values = world.on('persons', 'insert').single.args.single! as Map;
      expect(values['full_name'], 'Sitto Amina');
      expect(values['bio'], 'Baked every Friday');
      expect(values['created_by'], 'u1');
      expect(values['space_id'], 'sp');
    });
    test('createPerson failure', () async {
      world.responses['persons.insert'] = _boom;
      expect(await repo.createPerson(_newPerson), isA<Failed<Person>>());
    });

    test('updatePerson updates by id and never moves the space', () async {
      world.responses['persons.update'] = _person();
      final r = await repo.updatePerson(_newPerson);
      expect(r, isA<Success<Person>>());
      final call = world.on('persons', 'update').single;
      expect(call.chain.first, 'eq(id,p1)');
      expect((call.args.single! as Map).containsKey('space_id'), isFalse);
    });
    test('updatePerson failure', () async {
      world.responses['persons.update'] = _boom;
      expect(await repo.updatePerson(_newPerson), isA<Failed<Person>>());
    });
  });

  group('relationships', () {
    test('listRelationships maps the rows', () async {
      world.responses['relationships.select'] = [_relationship()];
      final r = await repo.listRelationships('sp');
      expect(
        (r as Success<List<Relationship>>).value.single.type,
        RelationshipType.parent,
      );
    });
    test('listRelationships failure', () async {
      world.responses['relationships.select'] = _boom;
      expect(
        await repo.listRelationships('sp'),
        isA<Failed<List<Relationship>>>(),
      );
    });

    test(
      'addRelationship inserts a pending row in the space of the user',
      () async {
        world.responses['family_memberships.select'] = [
          {'family_spaces': _space()},
        ];
        world.responses['relationships.insert'] = _relationship();
        final r = await repo.addRelationship(
          personId: 'p1',
          relatedPersonId: 'p2',
          type: RelationshipType.parent,
        );
        expect(r, isA<Success<Relationship>>());
        final values =
            world.on('relationships', 'insert').single.args.single! as Map;
        expect(values['status'], 'pending');
        expect(values['space_id'], 'sp');
        expect(values['type'], 'parent');
        expect(values['created_by'], 'u1');
      },
    );
    test('addRelationship failure', () async {
      world.responses['family_memberships.select'] = [
        {'family_spaces': _space()},
      ];
      world.responses['relationships.insert'] = _boom;
      expect(
        await repo.addRelationship(
          personId: 'p1',
          relatedPersonId: 'p2',
          type: RelationshipType.spouse,
        ),
        isA<Failed<Relationship>>(),
      );
    });

    test('confirmRelationship sets the status by id', () async {
      expect(await repo.confirmRelationship('r1'), isA<Success<void>>());
      final call = world.on('relationships', 'update').single;
      expect(call.args.single, {'status': 'confirmed'});
      expect(call.chain.single, 'eq(id,r1)');
    });
    test('confirmRelationship failure', () async {
      world.responses['relationships.update'] = _boom;
      expect(await repo.confirmRelationship('r1'), isA<Failed<void>>());
    });
  });
}
