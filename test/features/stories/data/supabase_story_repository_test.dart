import 'dart:io';

import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/data/story_repository.dart';
import 'package:family_stories/features/stories/data/supabase_story_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/fake_postgrest.dart';

class _MockClient extends Mock implements SupabaseClient {}

class _MockAuth extends Mock implements GoTrueClient {}

class _MockStorage extends Mock implements SupabaseStorageClient {}

class _MockFiles extends Mock implements StorageFileApi {}

Map<String, dynamic> _row({
  String id = 's1',
  String visibility = 'private',
  List<Map<String, String>> recipients = const [],
}) => {
  'id': id,
  'space_id': 'sp',
  'title': 'T',
  'visibility': visibility,
  'audio_path': 'sp/u1/$id/a.m4a',
  'duration_seconds': 9,
  'created_by': 'u1',
  'created_at': '2026-11-24T10:00:00Z',
  'story_narrators': [
    {'person_id': 'p1'},
  ],
  'story_people': <Map<String, String>>[],
  'story_photos': <Map<String, String>>[],
  'story_recipients': recipients,
};

Story _story({
  String id = 's1',
  StoryVisibility visibility = StoryVisibility.private,
  List<String> recipients = const [],
  List<int>? waveform,
}) => Story(
  id: id,
  spaceId: 'sp',
  title: 'T',
  visibility: visibility,
  audioPath: 'sp/u1/$id/a.m4a',
  durationSeconds: 9,
  createdBy: 'u1',
  createdAt: DateTime(2026),
  narratorIds: const ['p1'],
  recipientUserIds: recipients,
  waveform: waveform,
);

const _boom = PostgrestException(message: 'denied', code: '42501');

void main() {
  setUpAll(() {
    registerFallbackValue(const FileOptions());
    registerFallbackValue(File('x'));
  });

  late FakeWorld world;
  late StoryRepository repo;
  late _MockFiles files;

  setUp(() {
    world = FakeWorld();
    final client = _MockClient();
    final auth = _MockAuth();
    final storage = _MockStorage();
    files = _MockFiles();
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
    when(() => client.storage).thenReturn(storage);
    when(() => storage.from('story-audio')).thenReturn(files);
    repo = SupabaseStoryRepository(client);
  });

  group('listStories', () {
    test('asks for the space, newest first, and returns the rows', () async {
      world.responses['stories.select'] = [_row(id: 'a'), _row(id: 'b')];
      final r = await repo.listStories('sp');
      expect(r, isA<Success<List<Story>>>());
      expect((r as Success<List<Story>>).value.map((s) => s.id), ['a', 'b']);
      final call = world.on('stories', 'select').single;
      expect(call.chain.first, startsWith('eq(space_id,sp'));
      expect(call.chain.last, startsWith('order(created_at'));
    });

    test('topic and decade filters are sent to the server', () async {
      world.responses['stories.select'] = [_row()];
      await repo.listStories(
        'sp',
        filter: const StoryFilter(
          topic: 'funny_memories',
          yearFrom: 1950,
          yearTo: 1959,
        ),
      );
      final chain = world.on('stories', 'select').single.chain.join(' ');
      expect(chain, contains('eq(topic,funny_memories'));
      expect(chain, contains('gte(approx_year,1950'));
      expect(chain, contains('lte(approx_year,1959'));
    });

    test('narrator filter keeps only the stories of that narrator', () async {
      world.responses['stories.select'] = [_row(id: 'a')];
      final r = await repo.listStories(
        'sp',
        filter: const StoryFilter(narratorId: 'someone-else'),
      );
      expect((r as Success<List<Story>>).value, isEmpty);
    });

    test('a backend error becomes Failed', () async {
      world.responses['stories.select'] = _boom;
      expect(await repo.listStories('sp'), isA<Failed<List<Story>>>());
    });
  });

  group('getStory', () {
    test('returns the story', () async {
      world.responses['stories.select'] = [_row()];
      final r = await repo.getStory('s1');
      expect((r as Success<Story?>).value?.id, 's1');
      expect(
        world.on('stories', 'select').single.chain.first,
        startsWith('eq(id,s1'),
      );
    });

    test('no rows (or no access) is Success(null), not an error', () async {
      world.responses['stories.select'] = <Map<String, dynamic>>[];
      expect((await repo.getStory('s1') as Success<Story?>).value, isNull);
    });

    test('a backend error becomes Failed', () async {
      world.responses['stories.select'] = _boom;
      expect(await repo.getStory('s1'), isA<Failed<Story?>>());
    });
  });

  group('createStory', () {
    test('inserts the story, then its narrators, and reads it back', () async {
      world.responses['stories.insert'] = {'id': 's9'};
      world.responses['story_narrators.insert'] = null;
      world.responses['stories.select'] = [_row(id: 's9')];
      final r = await repo.createStory(_story(id: '', waveform: [1, 2, 3]));
      expect((r as Success<Story>).value.id, 's9');
      final insert = world.on('stories', 'insert').single;
      final values = insert.args.single! as Map;
      expect(values['created_by'], 'u1');
      expect(values['visibility'], 'private');
      expect(values['waveform'], [1, 2, 3]);
      expect(values.containsKey('id'), isFalse);
      final narrators =
          world.on('story_narrators', 'insert').single.args.single! as List;
      expect(narrators.single, {
        'story_id': 's9',
        'person_id': 'p1',
        'position': 0,
      });
    });

    test('"selected" stories insert exactly the chosen recipients', () async {
      world.responses['stories.insert'] = {'id': 's9'};
      world.responses['stories.select'] = [
        _row(id: 's9', visibility: 'selected'),
      ];
      await repo.createStory(
        _story(
          id: '',
          visibility: StoryVisibility.selected,
          recipients: const ['u2', 'u3'],
        ),
      );
      final grants =
          world.on('story_recipients', 'insert').single.args.single! as List;
      expect(grants, [
        {'story_id': 's9', 'grantee_user_id': 'u2', 'granted_by': 'u1'},
        {'story_id': 's9', 'grantee_user_id': 'u3', 'granted_by': 'u1'},
      ]);
    });

    test('private and family stories insert no recipients', () async {
      world.responses['stories.insert'] = {'id': 's9'};
      world.responses['stories.select'] = [_row(id: 's9')];
      await repo.createStory(_story(id: '', recipients: const ['u2']));
      expect(world.on('story_recipients', 'insert'), isEmpty);
    });

    test(
      'a backend error becomes Failed and nothing else is written',
      () async {
        world.responses['stories.insert'] = _boom;
        expect(await repo.createStory(_story(id: '')), isA<Failed<Story>>());
        expect(world.on('story_narrators', 'insert'), isEmpty);
      },
    );
  });

  group('updateStory', () {
    test('updates the row and re-syncs the join tables', () async {
      world.responses['stories.select'] = [_row()];
      final r = await repo.updateStory(_story().copyWith(title: 'New'));
      expect(r, isA<Success<Story>>());
      final update = world.on('stories', 'update').single;
      expect((update.args.single! as Map)['title'], 'New');
      expect((update.args.single! as Map).containsKey('visibility'), isFalse);
      expect(world.on('story_narrators', 'delete'), hasLength(1));
      expect(world.on('story_people', 'delete'), hasLength(1));
      expect(world.on('story_photos', 'delete'), hasLength(1));
      expect(world.on('story_narrators', 'insert'), hasLength(1));
    });

    test(
      'changing visibility removes old grants and sends the new value',
      () async {
        world.responses['stories.select'] = [_row()];
        await repo.updateStory(_story(visibility: StoryVisibility.family));
        expect(world.on('story_recipients', 'delete'), hasLength(1));
        expect(
          (world.on('stories', 'update').single.args.single!
              as Map)['visibility'],
          'family',
        );
      },
    );

    test('a backend error becomes Failed', () async {
      world.responses['stories.select'] = [_row()];
      world.responses['stories.update'] = _boom;
      expect(await repo.updateStory(_story()), isA<Failed<Story>>());
    });
  });

  group('deleteStory', () {
    test('deletes by id', () async {
      expect(await repo.deleteStory('s1'), isA<Success<void>>());
      final call = world.on('stories', 'delete').single;
      expect(call.chain.single, startsWith('eq(id,s1'));
    });

    test('a backend error becomes Failed', () async {
      world.responses['stories.delete'] = _boom;
      expect(await repo.deleteStory('s1'), isA<Failed<void>>());
    });
  });

  group('audio', () {
    test('createAudioUrl asks for a 15 minute signed URL', () async {
      when(
        () => files.createSignedUrl('p', 900),
      ).thenAnswer((_) async => 'https://x/y');
      final r = await repo.createAudioUrl('p');
      expect((r as Success<String>).value, 'https://x/y');
      verify(() => files.createSignedUrl('p', 900)).called(1);
    });

    test('createAudioUrl failure becomes Failed', () async {
      when(
        () => files.createSignedUrl(any(), any()),
      ).thenThrow(const StorageException('no'));
      expect(await repo.createAudioUrl('p'), isA<Failed<String>>());
    });

    test('deleteAudio removes the object', () async {
      when(() => files.remove(['p'])).thenAnswer((_) async => []);
      expect(await repo.deleteAudio('p'), isA<Success<void>>());
      verify(() => files.remove(['p'])).called(1);
    });

    test('deleteAudio failure becomes Failed', () async {
      when(() => files.remove(any())).thenThrow(const StorageException('no'));
      expect(await repo.deleteAudio('p'), isA<Failed<void>>());
    });

    test('uploadAudio failure becomes Failed', () async {
      when(
        () => files.upload(
          any<String>(),
          any<File>(),
          fileOptions: any(named: 'fileOptions'),
        ),
      ).thenThrow(const StorageException('no'));
      expect(
        await repo.uploadAudio('/tmp/none.wav', 'p'),
        isA<Failed<String>>(),
      );
    });
  });
}
