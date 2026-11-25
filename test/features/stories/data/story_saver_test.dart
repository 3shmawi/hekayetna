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
  late Directory tmp;
  late File take;
  final phases = <SavePhase>[];

  StorySaver saver({String? userId = 'u1'}) => StorySaver(
    stories: stories,
    family: family,
    drafts: drafts,
    userId: userId,
    joinTake: (_) async => take.path,
    newId: () => 'story-1',
  );

  setUpAll(() => registerFallbackValue(_FakeStory()));
  tearDown(() => tmp.deleteSync(recursive: true));

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('saver_');
    take = File('${tmp.path}/take.wav')..writeAsBytesSync([1, 2, 3, 4]);
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
      () => stories.audioSize(any()),
    ).thenAnswer((_) async => const Success(null));
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

  test(
    'an unauthorized create keeps the uploaded audio and the draft',
    () async {
      when(
        () => stories.createStory(any()),
      ).thenAnswer((_) async => const Failed(UnauthorizedFailure()));
      final r = await saver().save(
        draft,
        const StorySaveRequest(title: 't', visibility: StoryVisibility.private),
      );
      expect((r as Failed<Story>).failure, isA<UnauthorizedFailure>());
      expect(await drafts.get('d1'), isNotNull);
      verifyNever(() => stories.deleteAudio(any()));
    },
  );

  test(
    'an existing story missing its narrators is completed, not accepted',
    () async {
      final bare = Story(
        id: 'story-1',
        spaceId: 'sp1',
        title: 't',
        visibility: StoryVisibility.private,
        audioPath: 'sp1/u1/story-1/a.wav',
        durationSeconds: 95,
        topic: 'war',
        createdBy: 'u1',
        createdAt: DateTime(2026),
      );
      when(
        () => stories.getStory(any()),
      ).thenAnswer((_) async => Success(bare));
      when(
        () => stories.updateStory(any()),
      ).thenAnswer((i) async => Success(i.positionalArguments[0] as Story));
      final r = await saver().save(
        draft,
        const StorySaveRequest(
          title: 't',
          visibility: StoryVisibility.private,
          narratorIds: ['p1'],
        ),
      );
      expect(r, isA<Success<Story>>());
      final sent =
          verify(() => stories.createStory(captureAny())).captured.single
              as Story;
      expect(sent.narratorIds, ['p1']);
      verifyNever(() => stories.updateStory(any()));
      expect(await drafts.get('d1'), isNull);
    },
  );

  Story remote({
    String title = 't',
    StoryVisibility visibility = StoryVisibility.private,
    List<String> recipients = const [],
  }) => Story(
    id: 'story-1',
    spaceId: 'sp1',
    title: title,
    visibility: visibility,
    audioPath: 'sp1/u1/story-1/a.wav',
    durationSeconds: 95,
    topic: 'war',
    createdBy: 'u1',
    createdAt: DateTime(2026),
    recipientUserIds: recipients,
  );

  test('a story changed since is a conflict: untouched, draft kept', () async {
    when(
      () => stories.getStory(any()),
    ).thenAnswer((_) async => Success(remote(title: 'renamed by the user')));
    final r = await saver().save(
      draft,
      const StorySaveRequest(title: 't', visibility: StoryVisibility.private),
    );
    expect((r as Failed<Story>).failure, isA<ConflictFailure>());
    expect(await drafts.get('d1'), isNotNull);
    verifyNever(() => stories.createStory(any()));
    verifyNever(() => stories.updateStory(any()));
    verifyNever(() => stories.deleteAudio(any()));
  });

  test('a different privacy setting is a conflict, draft kept', () async {
    when(() => stories.getStory(any())).thenAnswer(
      (_) async => Success(remote(visibility: StoryVisibility.family)),
    );
    final r = await saver().save(
      draft,
      const StorySaveRequest(title: 't', visibility: StoryVisibility.private),
    );
    expect((r as Failed<Story>).failure, isA<ConflictFailure>());
    expect(await drafts.get('d1'), isNotNull);
  });

  test('extra remote recipients are a conflict, never "saved"', () async {
    when(() => stories.getStory(any())).thenAnswer(
      (_) async => Success(
        remote(
          visibility: StoryVisibility.selected,
          recipients: const ['u2', 'u9'],
        ),
      ),
    );
    final r = await saver().save(
      draft,
      const StorySaveRequest(
        title: 't',
        visibility: StoryVisibility.selected,
        recipientUserIds: ['u2'],
      ),
    );
    expect((r as Failed<Story>).failure, isA<ConflictFailure>());
    expect(await drafts.get('d1'), isNotNull);
    verifyNever(() => stories.createStory(any()));
  });

  test(
    'an identical existing story is saved and the draft is released',
    () async {
      when(
        () => stories.getStory(any()),
      ).thenAnswer((_) async => Success(remote()));
      final r = await saver().save(
        draft,
        const StorySaveRequest(title: 't', visibility: StoryVisibility.private),
      );
      expect(r, isA<Success<Story>>());
      expect(await drafts.get('d1'), isNull);
      verifyNever(() => stories.createStory(any()));
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

    StorySaver stable({
      Duration timeout = const Duration(seconds: 5),
      String? path,
      String user = 'u1',
    }) => StorySaver(
      stories: stories,
      family: family,
      drafts: drafts,
      userId: user,
      joinTake: (_) async => path ?? take.path,
      attemptTimeout: timeout,
    );

    Story storyOf(Object id) => Story(
      id: '$id',
      spaceId: 'sp1',
      title: 't',
      visibility: StoryVisibility.private,
      audioPath: 'sp1/u1/$id/a.wav',
      topic: 'war',
      durationSeconds: 95,
      createdBy: 'u1',
      createdAt: DateTime(2026),
    );

    test('id depends on owner, draft and audio content', () {
      final a = StorySaver.stableStoryId('u1', 'd1', 'aa');
      expect(a, StorySaver.stableStoryId('u1', 'd1', 'aa'));
      expect(a, isNot(StorySaver.stableStoryId('u1', 'd1', 'ab')));
      expect(a, isNot(StorySaver.stableStoryId('u1', 'd2', 'aa')));
      expect(a, isNot(StorySaver.stableStoryId('u2', 'd1', 'aa')));
      expect(a.length, 36);
    });

    test('same draft, same length, different bytes: different path', () async {
      final paths = <String>[];
      when(() => stories.uploadAudio(any(), any())).thenAnswer((i) async {
        paths.add(i.positionalArguments[1] as String);
        return Success(paths.last);
      });
      await stable().save(draft, req);
      await drafts.save(draft);
      take.writeAsBytesSync([4, 3, 2, 1]); // same length, other content
      await stable().save(draft, req); // a new saver, as after a restart
      expect(paths, hasLength(2));
      expect(paths[0], isNot(paths[1]));
    });

    test('same bytes after a restart: same path', () async {
      final paths = <String>[];
      when(() => stories.uploadAudio(any(), any())).thenAnswer((i) async {
        paths.add(i.positionalArguments[1] as String);
        return Success(paths.last);
      });
      await stable().save(draft, req);
      await drafts.save(draft);
      await stable().save(draft, req);
      expect(paths[0], paths[1]);
    });

    test('a double tap joins the running attempt', () async {
      final gate = Completer<Result<String>>();
      when(
        () => stories.uploadAudio(any(), any()),
      ).thenAnswer((_) => gate.future);
      final s = stable();
      final first = s.save(draft, req);
      final second = s.save(draft, req);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      gate.complete(const Success('p'));
      expect(await first, isA<Success<Story>>());
      expect(await second, isA<Success<Story>>());
      verify(() => stories.uploadAudio(any(), any())).called(1);
      verify(() => stories.createStory(any())).called(1);
    });

    test(
      'a slow upload that finishes later: next tap gets the result',
      () async {
        final gate = Completer<Result<String>>();
        when(
          () => stories.uploadAudio(any(), any()),
        ).thenAnswer((_) => gate.future);
        final s = stable(timeout: const Duration(milliseconds: 30));
        final first = await s.save(draft, req);
        expect((first as Failed<Story>).failure, isA<TimeoutFailure>());
        expect(await drafts.get('d1'), isNotNull);
        gate.complete(const Success('p'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        // the attempt finished on its own: draft gone, story created once
        expect(s.isSaving('d1'), isFalse);
        verify(() => stories.createStory(any())).called(1);
      },
    );

    test('upload never resolves but the story exists remotely', () async {
      final never = Completer<Result<String>>();
      when(
        () => stories.uploadAudio(any(), any()),
      ).thenAnswer((_) => never.future);
      final s = stable(timeout: const Duration(milliseconds: 30));
      final first = await s.save(draft, req);
      expect((first as Failed<Story>).failure, isA<TimeoutFailure>());
      // the write landed remotely meanwhile
      when(() => stories.getStory(any())).thenAnswer(
        (i) async => Success(storyOf(i.positionalArguments[0]! as Object)),
      );
      final second = await s.save(draft, req);
      expect(second, isA<Success<Story>>());
      expect(await drafts.get('d1'), isNull);
      verify(() => stories.uploadAudio(any(), any())).called(1); // no new write
      verifyNever(() => stories.createStory(any()));
      verifyNever(() => stories.deleteAudio(any()));
    });

    test(
      'create never resolves, story absent: a new attempt completes',
      () async {
        final never = Completer<Result<Story>>();
        var creates = 0;
        when(() => stories.createStory(any())).thenAnswer((i) {
          creates++;
          if (creates == 1) return never.future;
          return Future.value(Success(i.positionalArguments[0] as Story));
        });
        final s = stable(timeout: const Duration(milliseconds: 30));
        final first = await s.save(draft, req);
        expect((first as Failed<Story>).failure, isA<TimeoutFailure>());
        // object from attempt 1 is there with the same size
        when(
          () => stories.uploadAudio(any(), any()),
        ).thenAnswer((_) async => const Failed(ServerFailure()));
        when(
          () => stories.audioSize(any()),
        ).thenAnswer((_) async => const Success(4));
        final second = await s.save(draft, req);
        expect(second, isA<Success<Story>>());
        expect(creates, 2);
        verifyNever(() => stories.deleteAudio(any()));
        expect(await drafts.get('d1'), isNull);
      },
    );

    test(
      'superseded attempt failing late never deletes audio or draft',
      () async {
        final slowCreate = Completer<Result<Story>>();
        var creates = 0;
        when(() => stories.createStory(any())).thenAnswer((i) {
          creates++;
          if (creates == 1) return slowCreate.future;
          return Future.value(Success(i.positionalArguments[0] as Story));
        });
        final phases1 = <SavePhase>[];
        final s = stable(timeout: const Duration(milliseconds: 30));
        await s.save(draft, req, onPhase: phases1.add);
        when(
          () => stories.audioSize(any()),
        ).thenAnswer((_) async => const Success(4));
        when(
          () => stories.uploadAudio(any(), any()),
        ).thenAnswer((_) async => const Failed(ServerFailure()));
        final second = await s.save(draft, req);
        expect(second, isA<Success<Story>>());
        await drafts.save(draft); // newer flow still owns the draft
        phases1.clear();
        slowCreate.complete(
          const Failed(ServerFailure()),
        ); // old one fails late
        await Future<void>.delayed(const Duration(milliseconds: 30));
        verifyNever(() => stories.deleteAudio(any()));
        expect(await drafts.get('d1'), isNotNull);
        expect(phases1, isEmpty); // no UI state from the old attempt
      },
    );

    test('existing object of another size is not bound', () async {
      when(
        () => stories.uploadAudio(any(), any()),
      ).thenAnswer((_) async => const Failed(ServerFailure()));
      when(
        () => stories.audioSize(any()),
      ).thenAnswer((_) async => const Success(999));
      final r = await stable().save(draft, req);
      expect(r, isA<Failed<Story>>());
      verifyNever(() => stories.createStory(any()));
      verifyNever(() => stories.deleteAudio(any()));
      expect(await drafts.get('d1'), isNotNull);
    });

    test('existing object of the same size is reused, not deleted', () async {
      when(
        () => stories.uploadAudio(any(), any()),
      ).thenAnswer((_) async => const Failed(ServerFailure()));
      when(
        () => stories.audioSize(any()),
      ).thenAnswer((_) async => const Success(4));
      final r = await stable().save(draft, req);
      expect(r, isA<Success<Story>>());
      verifyNever(() => stories.deleteAudio(any()));
    });

    test('after a restart an already created story is reused', () async {
      when(() => stories.getStory(any())).thenAnswer(
        (i) async => Success(storyOf(i.positionalArguments[0]! as Object)),
      );
      final r = await stable().save(draft, req);
      expect(r, isA<Success<Story>>());
      verifyNever(() => stories.uploadAudio(any(), any()));
      verifyNever(() => stories.createStory(any()));
      expect(await drafts.get('d1'), isNull);
    });

    test('create fails but the story exists: reused, audio kept', () async {
      var calls = 0;
      when(() => stories.getStory(any())).thenAnswer(
        (i) async => ++calls == 1
            ? const Success(null)
            : Success(storyOf(i.positionalArguments[0]! as Object)),
      );
      when(
        () => stories.createStory(any()),
      ).thenAnswer((_) async => const Failed(TimeoutFailure()));
      final r = await stable().save(draft, req);
      expect(r, isA<Success<Story>>());
      verifyNever(() => stories.deleteAudio(any()));
    });

    test('uncertain create failure keeps the audio for the retry', () async {
      when(
        () => stories.createStory(any()),
      ).thenAnswer((_) async => const Failed(NetworkFailure()));
      final r = await stable().save(draft, req);
      expect(r, isA<Failed<Story>>());
      verifyNever(() => stories.deleteAudio(any()));
      expect(await drafts.get('d1'), isNotNull);
    });

    test(
      'definite rejection, story absent, no other attempt: upload removed',
      () async {
        when(
          () => stories.createStory(any()),
        ).thenAnswer((_) async => const Failed(ServerFailure()));
        await stable().save(draft, req);
        verify(() => stories.deleteAudio(any())).called(1);
      },
    );
  });
}
