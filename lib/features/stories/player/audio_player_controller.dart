import 'dart:async';

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/network/app_failure.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/player/audio_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Signed URLs live 15 minutes (see `createAudioUrl`); refresh a minute early.
const signedUrlLifetime = Duration(minutes: 14);

const playbackSpeeds = [0.75, 1.0, 1.25, 1.5];

enum PlayerStatus { idle, loading, playing, paused, completed, error }

@immutable
class PlayerState {
  const PlayerState({
    this.storyId,
    this.title,
    this.status = PlayerStatus.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
    this.failure,
  });

  final String? storyId;
  final String? title;
  final PlayerStatus status;
  final Duration position;
  final Duration duration;
  final double speed;
  final AppFailure? failure;

  bool get isPlaying => status == PlayerStatus.playing;

  /// 0 to 1, for progress bars.
  double get progress => duration.inMilliseconds == 0
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0, 1);

  PlayerState copyWith({
    PlayerStatus? status,
    Duration? position,
    Duration? duration,
    double? speed,
    AppFailure? Function()? failure,
  }) => PlayerState(
    storyId: storyId,
    title: title,
    status: status ?? this.status,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    speed: speed ?? this.speed,
    failure: failure == null ? this.failure : failure(),
  );
}

/// Override in tests with a fake engine.
final audioEngineProvider = Provider<AudioEngine>((ref) {
  final engine = JustAudioEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

/// Override in tests to move time forward.
final playerClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final audioPlayerControllerProvider =
    NotifierProvider<AudioPlayerController, PlayerState>(
      AudioPlayerController.new,
    );

/// The one player of the app: the story page, the feed cards and the mini
/// player all talk to it, so only one story plays at a time.
class AudioPlayerController extends Notifier<PlayerState> {
  final _subs = <StreamSubscription<Object?>>[];
  DateTime? _urlFetchedAt;
  String? _audioPath;
  var _refreshing = false;

  AudioEngine get _engine => ref.read(audioEngineProvider);

  @override
  PlayerState build() {
    final engine = ref.watch(audioEngineProvider);
    _subs
      ..add(
        engine.positionStream.listen((p) {
          if (state.storyId != null) state = state.copyWith(position: p);
        }),
      )
      ..add(
        engine.completed.listen((_) {
          if (state.storyId == null) return;
          state = state.copyWith(
            status: PlayerStatus.completed,
            position: state.duration,
          );
        }),
      )
      ..add(engine.errors.listen((_) => unawaited(_recoverFromError())));
    ref.onDispose(() {
      for (final s in _subs) {
        unawaited(s.cancel());
      }
      _subs.clear();
    });
    // Stops on sign-out (and when the user changes).
    ref.listen(currentUserIdProvider, (prev, next) {
      if (prev != next) unawaited(stop());
    });
    return const PlayerState();
  }

  /// Starts [story], or toggles it when it is already the loaded one.
  Future<void> playStory(Story story) async {
    if (state.storyId == story.id && state.status != PlayerStatus.error) {
      await toggle();
      return;
    }
    state = PlayerState(
      storyId: story.id,
      title: story.title,
      status: PlayerStatus.loading,
      duration: Duration(seconds: story.durationSeconds),
      speed: state.speed,
    );
    _audioPath = story.audioPath;
    final loaded = await _load(Duration.zero);
    if (!loaded || state.storyId != story.id) return;
    await _engine.setSpeed(state.speed);
    await _engine.play();
    state = state.copyWith(status: PlayerStatus.playing);
  }

  Future<void> toggle() async {
    if (state.storyId == null) return;
    switch (state.status) {
      case PlayerStatus.playing:
        await _engine.pause();
        state = state.copyWith(status: PlayerStatus.paused);
      case PlayerStatus.paused:
        await _resume(state.position);
      case PlayerStatus.completed:
        await _resume(Duration.zero);
      case PlayerStatus.error:
        await _resume(state.position);
      case PlayerStatus.idle || PlayerStatus.loading:
        break;
    }
  }

  Future<void> seek(Duration position) async {
    if (state.storyId == null) return;
    final target = position < Duration.zero
        ? Duration.zero
        : (state.duration > Duration.zero && position > state.duration
              ? state.duration
              : position);
    await _engine.seek(target);
    state = state.copyWith(position: target);
  }

  Future<void> setSpeed(double speed) async {
    state = state.copyWith(speed: speed);
    if (state.storyId != null) await _engine.setSpeed(speed);
  }

  Future<void> stop() async {
    if (state.storyId == null) return;
    state = PlayerState(speed: state.speed);
    _audioPath = null;
    _urlFetchedAt = null;
    await _engine.stop();
  }

  /// Resumes at [position]; a URL that is about to expire (or has) is
  /// replaced first, with no visible interruption.
  Future<void> _resume(Duration position) async {
    if (_urlExpired) {
      state = state.copyWith(status: PlayerStatus.loading);
      final ok = await _load(position);
      if (!ok) return;
      await _engine.setSpeed(state.speed);
    } else if (state.status == PlayerStatus.completed) {
      await _engine.seek(Duration.zero);
    }
    await _engine.play();
    state = state.copyWith(
      status: PlayerStatus.playing,
      position: position,
      failure: () => null,
    );
  }

  bool get _urlExpired {
    final at = _urlFetchedAt;
    return at == null ||
        ref.read(playerClockProvider)().difference(at) >= signedUrlLifetime;
  }

  /// Fetches a fresh signed URL and loads it at [position].
  Future<bool> _load(Duration position) async {
    final path = _audioPath;
    if (path == null) return false;
    final urlResult = await ref
        .read(storyRepositoryProvider)
        .createAudioUrl(path);
    switch (urlResult) {
      case Failed(:final failure):
        state = state.copyWith(
          status: PlayerStatus.error,
          failure: () => failure,
        );
        return false;
      case Success(:final value):
        _urlFetchedAt = ref.read(playerClockProvider)();
        try {
          await _engine.load(value, position: position);
        } on Object catch (error) {
          state = state.copyWith(
            status: PlayerStatus.error,
            failure: () => AppFailure.from(error),
          );
          return false;
        }
        final d = _engine.duration;
        if (d != null) state = state.copyWith(duration: d);
        return true;
    }
  }

  /// A 400/403 from the storage host means the signed URL expired: get a
  /// new one and carry on from the same position.
  Future<void> _recoverFromError() async {
    if (_refreshing || state.storyId == null) return;
    _refreshing = true;
    try {
      final position = _engine.position;
      final wasPlaying = state.status == PlayerStatus.playing;
      final ok = await _load(position);
      if (!ok) return;
      await _engine.setSpeed(state.speed);
      if (wasPlaying) {
        await _engine.play();
        state = state.copyWith(
          status: PlayerStatus.playing,
          position: position,
        );
      } else {
        state = state.copyWith(status: PlayerStatus.paused, position: position);
      }
    } finally {
      _refreshing = false;
    }
  }
}
