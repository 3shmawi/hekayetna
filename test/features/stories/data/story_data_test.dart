import 'package:family_stories/features/stories/data/demo_story_repository.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/data/story_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Story _story({
  String id = '',
  String title = 'A story',
  StoryVisibility visibility = StoryVisibility.private,
}) => Story(
  id: id,
  spaceId: 'demo-space',
  title: title,
  visibility: visibility,
  audioPath: 'demo-space/u/s/a.m4a',
  durationSeconds: 12,
  createdBy: 'demo-user',
  createdAt: DateTime(2026),
  topic: 'funny_memories',
  approxYear: 1990,
  narratorIds: const ['p-a'],
  peopleIds: const ['p-b'],
);

void main() {
  group('Story.fromJson', () {
    test('reads a row with its join tables', () {
      final story = Story.fromJson({
        'id': 's1',
        'space_id': 'sp',
        'title': 'Title',
        'description': null,
        'topic': 'childhood_first_home',
        'approx_date_label': 'summer 1975',
        'approx_year': 1975,
        'visibility': 'selected',
        'audio_path': 'sp/u/s1/a.m4a',
        'duration_seconds': 61,
        'created_by': 'u',
        'created_at': '2026-11-24T10:00:00Z',
        'story_narrators': [
          {'person_id': 'p1'},
        ],
        'story_people': [
          {'person_id': 'p2'},
        ],
        'story_photos': [
          {'photo_id': 'ph1'},
        ],
        'story_recipients': [
          {'grantee_user_id': 'u2'},
        ],
      });
      expect(story.visibility, StoryVisibility.selected);
      expect(story.durationSeconds, 61);
      expect(story.narratorIds, ['p1']);
      expect(story.peopleIds, ['p2']);
      expect(story.photoIds, ['ph1']);
      expect(story.recipientUserIds, ['u2']);
    });

    test('missing joins and duration default to empty / zero', () {
      final story = Story.fromJson({
        'id': 's1',
        'space_id': 'sp',
        'title': 'Title',
        'visibility': 'private',
        'audio_path': 'x',
        'created_by': 'u',
        'created_at': '2026-11-24T10:00:00Z',
      });
      expect(story.durationSeconds, 0);
      expect(story.narratorIds, isEmpty);
      expect(story.recipientUserIds, isEmpty);
    });

    test('an unknown visibility is rejected, never treated as shared', () {
      expect(
        () => Story.fromJson({
          'id': 's1',
          'space_id': 'sp',
          'title': 'Title',
          'visibility': 'public',
          'audio_path': 'x',
          'created_by': 'u',
          'created_at': '2026-11-24T10:00:00Z',
        }),
        throwsArgumentError,
      );
    });
  });

  test('StoryDraft survives a JSON round trip', () {
    final draft = StoryDraft(
      id: 'd1',
      filePath: '/tmp/d1.m4a',
      durationSeconds: 5,
      updatedAt: DateTime.utc(2026, 11, 24),
      narratorPersonId: 'p1',
      topic: 'funny_memories',
    );
    final back = StoryDraft.fromJson(draft.toJson());
    expect(back.id, draft.id);
    expect(back.filePath, draft.filePath);
    expect(back.durationSeconds, 5);
    expect(back.updatedAt, draft.updatedAt);
    expect(back.narratorPersonId, 'p1');
    expect(back.topic, 'funny_memories');
  });

  test('legacy draft JSON loads as one finished closed segment (AC-4)', () {
    final draft = StoryDraft.fromJson({
      'id': 'd1',
      'filePath': '/docs/drafts/d1.m4a',
      'narratorPersonId': 'p1',
      'topic': 'childhood_first_home',
      'durationSeconds': 95,
      'updatedAt': '2026-11-20T10:00:00.000',
    });
    expect(draft.status, DraftStatus.finished);
    expect(draft.segments, hasLength(1));
    expect(draft.segments.single.path, '/docs/drafts/d1.m4a');
    expect(draft.segments.single.durationMs, 95000);
    expect(draft.segments.single.closed, isTrue);
    expect(draft.filePath, '/docs/drafts/d1.m4a');
    expect(draft.durationSeconds, 95);
    expect(draft.createdAt, draft.updatedAt);
  });

  test('a draft built from the legacy shape is finished, not resumable', () {
    final draft = StoryDraft(
      id: 'd3',
      filePath: '/tmp/d3.m4a',
      durationSeconds: 12,
      updatedAt: DateTime(2026, 11, 23),
    );
    expect(draft.status, DraftStatus.finished);
    expect(draft.segments.single.closed, isTrue);
    expect(draft.duration, const Duration(seconds: 12));
  });

  test('segmented drafts round-trip status, promptId and createdAt', () {
    final created = DateTime.utc(2026, 11, 24, 9);
    final draft = StoryDraft(
      id: 'd2',
      segments: const [
        DraftSegment(path: '/x/seg-001-1.wav', durationMs: 30000, closed: true),
        DraftSegment(path: '/x/seg-002-2.wav', durationMs: 4200),
      ],
      status: DraftStatus.paused,
      narratorPersonId: 'p2',
      topic: 'funny_memories',
      promptId: 'prompt-7',
      createdAt: created,
      updatedAt: DateTime.utc(2026, 11, 24, 9, 5),
    );
    final back = StoryDraft.fromJson(draft.toJson());
    expect(back.status, DraftStatus.paused);
    expect(back.promptId, 'prompt-7');
    expect(back.createdAt, created);
    expect(back.segments, hasLength(2));
    expect(back.segments[1].closed, isFalse);
    expect(back.segments[1].durationMs, 4200);
    expect(back.duration, const Duration(milliseconds: 34200));
    expect(back.durationSeconds, 34);
    // legacy fields are still written for pre-spec-02 builds
    expect(draft.toJson()['filePath'], '/x/seg-001-1.wav');
    expect(draft.toJson()['durationSeconds'], 34);
  });

  group('DemoStoryRepository', () {
    late DemoStoryRepository repo;
    setUp(() => repo = DemoStoryRepository());

    test('starts with the labelled sample story', () async {
      final all = await repo.listStories('demo-space');
      expect(all, hasLength(1));
      expect(all.single.title, contains('(sample)'));
    });

    test('create, read, update and delete', () async {
      final created = await repo.createStory(_story(title: 'New'));
      expect(created.id, isNotEmpty);
      expect((await repo.getStory(created.id))?.title, 'New');

      final updated = await repo.updateStory(
        Story(
          id: created.id,
          spaceId: created.spaceId,
          title: 'Renamed',
          visibility: StoryVisibility.family,
          audioPath: created.audioPath,
          durationSeconds: created.durationSeconds,
          createdBy: created.createdBy,
          createdAt: created.createdAt,
        ),
      );
      expect(updated.title, 'Renamed');
      expect(
        (await repo.getStory(created.id))?.visibility,
        StoryVisibility.family,
      );

      await repo.deleteStory(created.id);
      expect(await repo.getStory(created.id), isNull);
    });

    test('updating a missing story fails', () async {
      expect(() => repo.updateStory(_story(id: 'nope')), throwsStateError);
    });

    test('filters by narrator, topic, person and year', () async {
      await repo.createStory(_story(title: 'Mine'));
      Future<List<String>> titles(StoryFilter f) async => [
        for (final s in await repo.listStories('demo-space', filter: f))
          s.title,
      ];
      expect(await titles(const StoryFilter(narratorId: 'p-a')), ['Mine']);
      expect(await titles(const StoryFilter(topic: 'funny_memories')), [
        'Mine',
      ]);
      expect(await titles(const StoryFilter(personId: 'p-b')), ['Mine']);
      expect(await titles(const StoryFilter(yearFrom: 1980)), ['Mine']);
      expect(await titles(const StoryFilter(yearTo: 1960)), [
        'The first Om Ali (sample)',
      ]);
    });

    test('audio helpers stay local', () async {
      expect(await repo.createAudioUrl('a.m4a'), 'demo://audio/a.m4a');
      expect(await repo.uploadAudio('/tmp/a.m4a', 'p/a.m4a'), 'p/a.m4a');
      await repo.deleteAudio('p/a.m4a');
    });
  });
}
