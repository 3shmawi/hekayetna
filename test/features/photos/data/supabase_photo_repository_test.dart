import 'dart:io';

import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/features/photos/data/models.dart';
import 'package:family_stories/features/photos/data/photo_repository.dart';
import 'package:family_stories/features/photos/data/supabase_photo_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/fake_postgrest.dart';

class _MockClient extends Mock implements SupabaseClient {}

class _MockAuth extends Mock implements GoTrueClient {}

class _MockStorage extends Mock implements SupabaseStorageClient {}

class _MockFiles extends Mock implements StorageFileApi {}

const _boom = PostgrestException(message: 'denied', code: '42501');

Map<String, dynamic> _row({
  String id = 'ph1',
  List<String> people = const [],
}) => {
  'id': id,
  'space_id': 'sp',
  'image_path': 'sp/u1/$id.jpg',
  'visibility': 'family',
  'uploaded_by': 'u1',
  'photo_people': [
    for (final p in people) {'person_id': p},
  ],
};

Photo _photo({List<String> people = const []}) => Photo(
  id: '',
  spaceId: 'sp',
  imagePath: 'sp/u1/a.jpg',
  visibility: PhotoVisibility.family,
  uploadedBy: 'u1',
  caption: 'Eid',
  personIds: people,
);

void main() {
  setUpAll(() {
    registerFallbackValue(File('x'));
  });

  late FakeWorld world;
  late PhotoRepository repo;
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
    when(() => storage.from('family-photos')).thenReturn(files);
    repo = SupabasePhotoRepository(client);
  });

  group('listPhotos', () {
    test('asks for the space and returns the rows', () async {
      world.responses['photos.select'] = [_row(), _row(id: 'ph2')];
      final r = await repo.listPhotos('sp');
      expect((r as Success<List<Photo>>).value, hasLength(2));
      expect(
        world.on('photos', 'select').single.chain.first,
        'eq(space_id,sp)',
      );
    });
    test('personId keeps only photos of that person', () async {
      world.responses['photos.select'] = [
        _row(people: ['p1']),
        _row(id: 'ph2', people: ['p2']),
      ];
      final r = await repo.listPhotos('sp', personId: 'p2');
      expect((r as Success<List<Photo>>).value.single.id, 'ph2');
    });
    test('a backend error becomes Failed', () async {
      world.responses['photos.select'] = _boom;
      expect(await repo.listPhotos('sp'), isA<Failed<List<Photo>>>());
    });
  });

  group('createPhoto', () {
    test('inserts the photo, links people and reads it back', () async {
      world.responses['photos.insert'] = {'id': 'ph9'};
      world.responses['photos.select'] = [
        _row(id: 'ph9', people: ['p1']),
      ];
      final r = await repo.createPhoto(_photo(people: ['p1']));
      expect((r as Success<Photo>).value.id, 'ph9');
      final values = world.on('photos', 'insert').single.args.single! as Map;
      expect(values['uploaded_by'], 'u1');
      expect(values['visibility'], 'family');
      expect(values.containsKey('id'), isFalse);
      expect(world.on('photo_people', 'insert').single.args.single, [
        {'photo_id': 'ph9', 'person_id': 'p1'},
      ]);
    });
    test('no people means no link rows', () async {
      world.responses['photos.insert'] = {'id': 'ph9'};
      world.responses['photos.select'] = [_row(id: 'ph9')];
      await repo.createPhoto(_photo());
      expect(world.on('photo_people', 'insert'), isEmpty);
    });
    test('a backend error becomes Failed', () async {
      world.responses['photos.insert'] = _boom;
      expect(await repo.createPhoto(_photo()), isA<Failed<Photo>>());
      expect(world.on('photo_people', 'insert'), isEmpty);
    });
  });

  group('storage', () {
    test('createImageUrl asks for a 15 minute signed URL', () async {
      when(
        () => files.createSignedUrl('p', 900),
      ).thenAnswer((_) async => 'https://x/y');
      final r = await repo.createImageUrl('p');
      expect((r as Success<String>).value, 'https://x/y');
    });
    test('createImageUrl failure', () async {
      when(
        () => files.createSignedUrl(any(), any()),
      ).thenThrow(const StorageException('no'));
      expect(await repo.createImageUrl('p'), isA<Failed<String>>());
    });
    test('deleteImage removes the object', () async {
      when(() => files.remove(['p'])).thenAnswer((_) async => []);
      expect(await repo.deleteImage('p'), isA<Success<void>>());
      verify(() => files.remove(['p'])).called(1);
    });
    test('deleteImage failure', () async {
      when(() => files.remove(any())).thenThrow(const StorageException('no'));
      expect(await repo.deleteImage('p'), isA<Failed<void>>());
    });
    test('uploadImage failure', () async {
      when(
        () => files.upload(any<String>(), any<File>()),
      ).thenThrow(const StorageException('no'));
      expect(
        await repo.uploadImage('/tmp/none.jpg', 'p'),
        isA<Failed<String>>(),
      );
    });
  });
}
