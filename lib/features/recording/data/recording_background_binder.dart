import 'dart:async';

import 'package:family_stories/features/recording/data/recorder_service.dart';
import 'package:family_stories/features/recording/data/recording_background.dart';

/// Ties the recorder to the background notification: shown while a take is
/// recording or paused, removed when it ends, and its buttons drive the
/// recorder. Never starts a recording by itself.
class RecordingBackgroundBinder {
  RecordingBackgroundBinder({
    required this._recorder,
    required this._background,
    required this._labels,
  }) {
    _state = _recorder.watch().listen(_onState);
    _commands = _background.commands.listen(_onCommand);
  }

  final RecorderService _recorder;
  final RecordingBackground _background;
  final BackgroundLabels Function() _labels;
  late final StreamSubscription<RecorderState> _state;
  late final StreamSubscription<BackgroundCommand> _commands;
  bool _shown = false;
  bool _askedPermission = false;

  /// False once the user denied notifications: the screen shows a one-line
  /// hint and recording continues in the foreground only.
  bool notificationsDenied = false;

  Future<void> _onState(RecorderState s) async {
    switch (s.status) {
      case RecorderStatus.recording:
      case RecorderStatus.paused:
        if (!_askedPermission) {
          _askedPermission = true;
          notificationsDenied = !await _background
              .ensureNotificationPermission();
        }
        if (notificationsDenied) return;
        _shown = true;
        await _background.show(
          _labels(),
          paused: s.status == RecorderStatus.paused,
        );
      case RecorderStatus.idle:
      case RecorderStatus.stopped:
      case RecorderStatus.failed:
        if (_shown) {
          _shown = false;
          await _background.hide();
        }
    }
  }

  Future<void> _onCommand(BackgroundCommand command) async {
    switch (command) {
      case BackgroundCommand.pause:
        await _recorder.pause();
      case BackgroundCommand.resume:
        await _recorder.resume();
      case BackgroundCommand.stop:
        await _recorder.stop();
    }
  }

  Future<void> dispose() async {
    await _state.cancel();
    await _commands.cancel();
    if (_shown) await _background.hide();
  }
}
