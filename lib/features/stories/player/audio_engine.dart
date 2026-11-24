import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// The slice of an audio player the controller needs. Tests use a fake.
abstract class AudioEngine {
  /// Loads [url] and seeks to [position] before any playback.
  Future<void> load(String url, {Duration position = Duration.zero});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> stop();
  Future<void> dispose();

  Duration get position;
  Duration? get duration;
  Stream<Duration> get positionStream;
  Stream<void> get completed;

  /// Playback errors, for example a signed URL that has expired.
  Stream<Object> get errors;
}

class JustAudioEngine implements AudioEngine {
  JustAudioEngine() {
    _stateSub = _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        _completed.add(null);
      }
    }, onError: _errors.add);
  }

  final _player = AudioPlayer();
  final _completed = StreamController<void>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  late final StreamSubscription<PlayerState> _stateSub;

  @override
  Future<void> load(String url, {Duration position = Duration.zero}) async {
    await _player.setUrl(url, initialPosition: position);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() async {
    await _stateSub.cancel();
    await _completed.close();
    await _errors.close();
    await _player.dispose();
  }

  @override
  Duration get position => _player.position;

  @override
  Duration? get duration => _player.duration;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<void> get completed => _completed.stream;

  @override
  Stream<Object> get errors => _errors.stream;
}
