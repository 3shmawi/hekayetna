import 'dart:async';
import 'dart:io';

import 'package:family_stories/core/network/app_failure.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/features/family/data/family_repository.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/recording/data/memory_draft_store.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/data/story_repository.dart';
import 'package:family_stories/features/stories/data/story_saver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Stories extends Mock implements StoryRepository {}

class _Family extends Mock implements FamilyRepository {}

class _FakeStory extends Fake implements Story {}

void main() {
  late _Stories stories;
  late _Family family;
  late MemoryDraftStore drafts;
  late StoryDraft draft;
  late FamilySpace space;
  final phases = <SavePhase>[];

  StorySaver saver({String? userId = 'u1'}) => StorySaver(
    stories: stories,
    family: family,
    drafts: drafts,
    userId: userId,
    joinTake: (_) async => '/tmp/take.wav',
    newId: () => 'story-1',
  );

  setUpAll(() => registerFallbackValue(_FakeStory()));

  setUp(() async {
    stories = _Stories();
    family = _Family();
    drafts = MemoryDraftStore();
    phases.clear();
    draft = StoryDraft(
      id: 'd1',
      filePath: '/tmp/take.wav',
      durationSeconds: 95,
      updatedAt: DateTime(2026),
      topic: 'war',
    );
    await drafts.save(draft);
    space = const FamilySpace(id: 'sp1', name: 'Family', inviteCode: 'X');
    when(() => family.getMySpace()).thenAnswer((_) async => Success(space));
    when(
      () => stories.getStory(any()),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => stories.uploadAudio(any(), any()),
    ).thenAnswer((i) async => Success(i.positionalArguments[1] as String));
    when(
      () => stories.createStory(any()),
    ).thenAnswer((i) async => Success(i.positionalArguments[0] as Story));
    when(
      () => stories.deleteAudio(any()),
    ).thenAnswer((_) async => const Success(null));
  });

  test(
    'success: uploads, creates with recipients and waveform, drops draft',
    () async {
      final wave = List.filled(64, 40);
      final result = await saver().save(
        draft,
        StorySaveRequest(
          title: '  Sitto at the stove  ',
          description: ' ',
          dateLabel: 'early 60s',
          year: 1962,
          visibility: StoryVisibility.selected,
          narratorIds: const ['p1'],
          peopleIds: const ['p2'],
          recipientUserIds: const ['u2', 'u3'],
          photoIds: const ['ph1'],
          waveform: wave,
        ),
        onPhase: phases.add,
      );
      expect(result, isA<Success<Story>>());
      final story = (result as Success<Story>).value;
      expect(story.id, 'story-1');
      expect(story.title, 'Sitto at the stove');
      expect(story.description, isNull);
      expect(story.topic, 'war');
      expect(story.approxYear, 1962);
      expect(story.durationSeconds, 95);
      expect(story.audioPath, 'sp1/u1/story-1/a.wav');
      expect(story.recipientUserIds, ['u2', 'u3']);
      expect(story.narratorIds, ['p1']);
      expect(story.peopleIds, ['p2']);
      expect(story.photoIds, ['ph1']);
      expect(story.waveform, wave);
      expect(phases, [
        SavePhase.preparing,
        SavePhase.uploading,
        SavePhase.creating,
      ]);
      expect(await drafts.get('d1'), isNull);
      verifyNever(() => stories.deleteAudio(any()));
    },
  );

  test('create failure leaves the local recording file untouched', () async {
    final dir = Directory.systemTemp.createTempSync('saver_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final take = File('${dir.path}/take.wav')..writeAsBytesSync([1, 2, 3, 4]);
    final local = StoryDraft(
      id: 'd1',
      filePath: take.path,
      durationSeconds: 95,
      updatedAt: DateTime(2026),
      topic: 'war',
    );
    await drafts.save(local);
    when(
      () => stories.createStory(any()),
    ).thenAnswer((_) async => const Failed(ServerFailure()));
    final r =
        await StorySaver(
          stories: stories,
          family: family,
          drafts: drafts,
          userId: 'u1',
          joinTake: (_) async => take.path,
          newId: () => 'story-1',
        ).save(
          local,
          const StorySaveRequest(
            title: 't',
            visibility: StoryVisibility.private,
          ),
        );
    expect(r, isA<Failed<Story>>());
    // Only the remote copy is removed; the phone keeps the real audio.
    verify(() => stories.deleteAudio('sp1/u1/story-1/a.wav')).called(1);
    expect(take.existsSync(), isTrue);
    expect(take.readAsBytesSync(), [1, 2, 3, 4]);
    expect(await drafts.get('d1'), isNotNull);
  });

  test('only me and whole family never send recipients', () async {
    for (final v in [StoryVisibility.private, StoryVisibility.family]) {
      final r = await saver().save(
        draft,
        StorySaveRequest(
          title: 't',
          visibility: v,
          recipientUserIds: const ['u2'],
        ),
      );
      expect((r as Success<Story>).value.recipientUserIds, isEmpty);
      await drafts.save(draft);
    }
  });

  test('upload failure keeps the draft and creates nothing', () async {
    when(
      () => stories.uploadAudio(any(), any()),
    ).thenAnswer((_) async => const Failed(NetworkFailure()));
    final r = await saver().save(
      draft,
      const StorySaveRequest(title: 't', visibility: StoryVisibility.private),
    );
    expect(r, isA<Failed<Story>>());
    expect(await drafts.get('d1'), isNotNull);
    verifyNever(() => stories.createStory(any()));
  });

  test(
    'create failure removes the uploaded audio and keeps the draft',
    () async {
      when(
        () => stories.createStory(any()),
      ).thenAnswer((_) async => const Failed(ServerFailure()));
      final r = await saver().save(
        draft,
        const StorySaveRequest(title: 't', visibility: StoryVisibility.private),
      );
      expect(r, isA<Failed<Story>>());
      expect(await drafts.get('d1'), isNotNull);
      verify(() => stories.deleteAudio('sp1/u1/story-1/a.wav')).called(1);
    },
  );

  test('no session fails before anything is read or uploaded', () async {
    final r = await saver(userId: null).save(
      draft,
      const StorySaveRequest(title: 't', visibility: StoryVisibility.private),
    );
    expect((r as Failed<Story>).failure, isA<UnauthorizedFailure>());
    verifyNever(() => family.getMySpace());
    verifyNever(() => stories.uploadAudio(any(), any()));
  });

  test('a join failure is reported and the draft stays', () async {
    final s = StorySaver(
      stories: stories,
      family: family,
      drafts: drafts,
      userId: 'u1',
      joinTake: (_) async => throw const FileSystemException('empty'),
    );
    final r = await s.save(
      draft,
      const StorySaveRequest(title: 't', visibility: StoryVisibility.private),
    );
    expect(r, isA<Failed<Story>>());
    expect(await drafts.get('d1'), isNotNull);
    verifyNever(() => stories.uploadAudio(any(), any()));
  });

  group('retry and idempotency', () {
    const req = StorySaveRequest(
      title: 't',
      visibility: StoryVisibility.private,
    );

    StorySaver stable({Duration timeout = const Duration(seconds: 5)}) =>
        StorySaver(
          stories: stories,
          family: family,
          drafts: drafts,
          userId: 'u1',
          joinTake: (_) async => '/tmp/take.wav',
          attemptTimeout: timeout,
        );

    test('same draft and audio give the same id, other audio another', () {
      final a = StorySaver.stableStoryId('d1', 100);
      expect(a, StorySaver.stableStoryId('d1', 100));
      expect(a, isNot(StorySaver.stableStoryId('d1', 101)));
      expect(a, isNot(StorySaver.stableStoryId('d2', 100)));
      expect(a.length, 36);
      expect(
        a,
        matches(
          RegExp('^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'),
        ),
      );
    });

    test(
      'a double tap joins the running attempt: one upload, one create',
      () async {
        final gate = Completer<Result<String>>();
        when(
          () => stories.uploadAudio(any(), any()),
        ).thenAnswer((_) => gate.future);
        final s = stable();
        final first = s.save(draft, req);
        final second = s.save(draft, req);
        await Future<void>.delayed(Duration.zero);
        gate.complete(const Success('p'));
        expect(await first, isA<Success<Story>>());
        expect(await second, isA<Success<Story>>());
        verify(() => stories.uploadAudio(any(), any())).called(1);
        verify(() => stories.createStory(any())).called(1);
      },
    );

    test(
      'a timeout does not cancel the write; a retry gets its real result',
      () async {
        final gate = Completer<Result<String>>();
        when(
          () => stories.uploadAudio(any(), any()),
        ).thenAnswer((_) => gate.future);
        final s = stable(timeout: const Duration(milliseconds: 20));
        final first = await s.save(draft, req);
        expect(first, isA<Failed<Story>>());
        expect((first as Failed<Story>).failure, isA<TimeoutFailure>());
        expect(s.isSaving('d1'), isTrue);
        expect(await drafts.get('d1'), isNotNull); // draft kept
        // the late upload completes, then the retry joins the same attempt
        final retry = s.save(draft, req);
        gate.complete(const Success('p'));
        expect(await retry, isA<Success<Story>>());
        verify(() => stories.uploadAudio(any(), any())).called(1);
        verify(() => stories.createStory(any())).called(1);
        expect(s.isSaving('d1'), isFalse);
        expect(await drafts.get('d1'), isNull);
      },
    );

    test(
      'after a restart an already created story is reused, nothing is written',
      () async {
        final existing = Story(
          id: 'x',
          spaceId: 'sp1',
          title: 'earlier',
          visibility: StoryVisibility.private,
          audioPath: 'p',
          durationSeconds: 1,
          createdBy: 'u1',
          createdAt: DateTime(2026),
        );
        when(
          () => stories.getStory(any()),
        ).thenAnswer((_) async => Success(existing));
        final r = await stable().save(draft, req);
        expect((r as Success<Story>).value.title, 'earlier');
        verifyNever(() => stories.uploadAudio(any(), any()));
        verifyNever(() => stories.createStory(any()));
        verifyNever(() => stories.deleteAudio(any()));
        expect(await drafts.get('d1'), isNull);
      },
    );

    test(
      'create fails but the story exists (late write): reused, audio kept',
      () async {
        final existing = Story(
          id: 'x',
          spaceId: 'sp1',
          title: 'late',
          visibility: StoryVisibility.private,
          audioPath: 'p',
          durationSeconds: 1,
          createdBy: 'u1',
          createdAt: DateTime(2026),
        );
        var calls = 0;
        when(() => stories.getStory(any())).thenAnswer(
          (_) async => ++calls == 1 ? const Success(null) : Success(existing),
        );
        when(
          () => stories.createStory(any()),
        ).thenAnswer((_) async => const Failed(TimeoutFailure()));
        final r = await stable().save(draft, req);
        expect((r as Success<Story>).value.title, 'late');
        verifyNever(() => stories.deleteAudio(any()));
      },
    );

    test(
      'uncertain create failure keeps the uploaded audio for the retry',
      () async {
        when(
          () => stories.createStory(any()),
        ).thenAnswer((_) async => const Failed(NetworkFailure()));
        final r = await stable().save(draft, req);
        expect(r, isA<Failed<Story>>());
        verifyNever(() => stories.deleteAudio(any()));
        expect(await drafts.get('d1'), isNotNull);
      },
    );

    test('definite rejection with no story removes only the upload', () async {
      when(
        () => stories.createStory(any()),
      ).thenAnswer((_) async => const Failed(ServerFailure()));
      await stable().save(draft, req);
      verify(() => stories.deleteAudio(any())).called(1);
    });
  });
}
