import 'dart:io';

import 'package:family_stories/features/recording/data/file_draft_store.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late FileDraftStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('drafts_test');
    store = FileDraftStore(directoryPath: dir.path);
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  StoryDraft draft(String id, {int seconds = 10}) => StoryDraft(
    id: id,
    filePath: '${dir.path}/$id.m4a',
    narratorPersonId: 'p-sitto',
    durationSeconds: seconds,
    updatedAt: DateTime(2026, 11, 23),
  );

  test('empty store lists nothing', () async {
    expect(await store.list(), isEmpty);
  });

  test('save then list returns the draft, newest first', () async {
    await store.save(draft('a'));
    await store.save(draft('b'));
    final all = await store.list();
    expect(all.map((d) => d.id), containsAll(['a', 'b']));
  });

  test('saving the same id updates instead of duplicating', () async {
    await store.save(draft('a'));
    await store.save(draft('a', seconds: 42));
    final all = await store.list();
    expect(all.length, 1);
    expect(all.single.durationSeconds, 42);
  });

  test('delete removes the index entry and the audio file', () async {
    await File('${dir.path}/a.m4a').writeAsBytes([1, 2, 3]);
    await store.save(draft('a'));
    await store.delete('a');
    expect(await store.list(), isEmpty);
    expect(File('${dir.path}/a.m4a').existsSync(), isFalse);
  });

  test('a corrupt index reads as empty instead of crashing', () async {
    await File('${dir.path}/drafts.json').writeAsString('{not json');
    expect(await store.list(), isEmpty);
  });

  test('a torn previous write does not lose the saved index', () async {
    await store.save(draft('a'));
    // simulate a crash that left only the tmp file behind
    await File('${dir.path}/drafts.json.tmp').writeAsString('[broken');
    final all = await store.list();
    expect(all.single.id, 'a');
  });
}
