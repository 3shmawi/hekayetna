import 'dart:async';

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/network/app_failure.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/features/stories/data/demo_story_repository.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/player/audio_engine.dart';
import 'package:family_stories/features/stories/player/audio_player_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeEngine implements AudioEngine {
  final log = <String>[];
  final _pos = StreamController<Duration>.broadcast();
  final _done = StreamController<void>.broadcast();
  final _err = StreamController<Object>.broadcast();
  @override
  Duration position = Duration.zero;
  @override
  Duration? duration = const Duration(seconds: 100);
  double speed = 1;

  @override
  Future<void> load(String url, {Duration position = Duration.zero}) async {
    log.add('load $url @${position.inSeconds}');
    this.position = position;
  }

  @override
  Future<void> play() async => log.add('play');
  @override
  Future<void> pause() async => log.add('pause');
  @override
  Future<void> seek(Duration p) async {
    log.add('seek ${p.inSeconds}');
    position = p;
  }

  @override
  Future<void> setSpeed(double s) async {
    speed = s;
    log.add('speed $s');
  }

  @override
  Future<void> stop() async => log.add('stop');
  @override
  Future<void> dispose() async {}
  @override
  Stream<Duration> get positionStream => _pos.stream;
  @override
  Stream<void> get completed => _done.stream;
  @override
  Stream<Object> get errors => _err.stream;

  void emitPosition(Duration p) {
    position = p;
    _pos.add(p);
  }

  void emitCompleted() => _done.add(null);
  void emitError() => _err.add('403');
}

class UrlRepo extends DemoStoryRepository {
  int urls = 0;
  bool fail = false;
  @override
  Future<Result<String>> createAudioUrl(String audioPath) async {
    if (fail) return const Failed(NetworkFailure());
    urls++;
    return Success('https://signed/$urls');
  }
}

Story _story(String id) => Story(
  id: id,
  spaceId: 's',
  title: 'Story $id',
  visibility: StoryVisibility.family,
  audioPath: 'p/$id.wav',
  durationSeconds: 100,
  createdBy: 'u',
  createdAt: DateTime(2026),
);

void main() {
  late FakeEngine engine;
  late UrlRepo repo;
  late DateTime now;
  late ProviderContainer c;

  setUp(() {
    engine = FakeEngine();
    repo = UrlRepo();
    now = DateTime(2026, 1, 1, 12);
    c = ProviderContainer(
      overrides: [
        audioEngineProvider.overrideWithValue(engine),
        storyRepositoryProvider.overrideWithValue(repo),
        playerClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(c.dispose);
    c.listen(audioPlayerControllerProvider, (_, _) {});
  });

  PlayerState state() => c.read(audioPlayerControllerProvider);
  AudioPlayerController ctl() => c.read(audioPlayerControllerProvider.notifier);

  test('play, pause and resume', () async {
    await ctl().playStory(_story('a'));
    expect(state().status, PlayerStatus.playing);
    expect(engine.log, ['load https://signed/1 @0', 'speed 1.0', 'play']);
    await ctl().toggle();
    expect(state().status, PlayerStatus.paused);
    await ctl().toggle();
    expect(state().status, PlayerStatus.playing);
    expect(repo.urls, 1);
  });

  test('tapping the playing story again pauses it', () async {
    await ctl().playStory(_story('a'));
    await ctl().playStory(_story('a'));
    expect(state().status, PlayerStatus.paused);
  });

  test('seek clamps to the story length', () async {
    await ctl().playStory(_story('a'));
    await ctl().seek(const Duration(seconds: 30));
    expect(state().position, const Duration(seconds: 30));
    await ctl().seek(const Duration(seconds: 500));
    expect(state().position, const Duration(seconds: 100));
    await ctl().seek(const Duration(seconds: -4));
    expect(state().position, Duration.zero);
  });

  test('speed is kept across stories', () async {
    await ctl().playStory(_story('a'));
    await ctl().setSpeed(1.5);
    expect(engine.speed, 1.5);
    await ctl().playStory(_story('b'));
    expect(state().speed, 1.5);
    expect(engine.speed, 1.5);
    expect(state().storyId, 'b');
  });

  test('position and completion follow the engine', () async {
    await ctl().playStory(_story('a'));
    engine.emitPosition(const Duration(seconds: 12));
    await Future<void>.delayed(Duration.zero);
    expect(state().position, const Duration(seconds: 12));
    engine.emitCompleted();
    await Future<void>.delayed(Duration.zero);
    expect(state().status, PlayerStatus.completed);
    await ctl().toggle();
    expect(state().status, PlayerStatus.playing);
  });

  test(
    'resuming after the URL expired refetches and keeps the position',
    () async {
      await ctl().playStory(_story('a'));
      engine.emitPosition(const Duration(seconds: 40));
      await Future<void>.delayed(Duration.zero);
      await ctl().toggle();
      now = now.add(const Duration(minutes: 16));
      await ctl().toggle();
      expect(repo.urls, 2);
      expect(engine.log, contains('load https://signed/2 @40'));
      expect(state().status, PlayerStatus.playing);
    },
  );

  test(
    'a playback error refreshes the URL and continues from the same position',
    () async {
      await ctl().playStory(_story('a'));
      engine.emitPosition(const Duration(seconds: 25));
      await Future<void>.delayed(Duration.zero);
      engine.emitError();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repo.urls, 2);
      expect(engine.log, contains('load https://signed/2 @25'));
      expect(state().status, PlayerStatus.playing);
      expect(state().position, const Duration(seconds: 25));
    },
  );

  test('a failed URL fetch shows an error state', () async {
    repo.fail = true;
    await ctl().playStory(_story('a'));
    expect(state().status, PlayerStatus.error);
    expect(state().failure, isA<NetworkFailure>());
  });

  test('stop clears the player', () async {
    await ctl().playStory(_story('a'));
    await ctl().stop();
    expect(state().storyId, isNull);
    expect(engine.log.last, 'stop');
  });
}
