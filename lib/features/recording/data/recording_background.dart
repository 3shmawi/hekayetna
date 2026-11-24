import 'dart:async';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// What the user tapped in the recording notification.
enum BackgroundCommand { pause, resume, stop }

/// Localised text for the recording notification.
class BackgroundLabels {
  const BackgroundLabels({
    required this.title,
    required this.pausedTitle,
    required this.pause,
    required this.resume,
    required this.stop,
  });

  final String title;
  final String pausedTitle;
  final String pause;
  final String resume;
  final String stop;
}

/// Keeps a recording alive while the app is in the background (Android
/// foreground service of type `microphone`; iOS uses the `audio` background
/// mode and needs nothing here). Abstract so the binder is unit-testable.
abstract class RecordingBackground {
  /// Notification button presses.
  Stream<BackgroundCommand> get commands;

  /// Asks for the Android 13+ notification permission. False when denied:
  /// recording then still works in the foreground (spec 02).
  Future<bool> ensureNotificationPermission();

  Future<void> show(BackgroundLabels labels, {required bool paused});
  Future<void> hide();
}

/// No background work: iOS (audio mode) and tests.
class NoRecordingBackground implements RecordingBackground {
  @override
  Stream<BackgroundCommand> get commands => const Stream.empty();

  @override
  Future<bool> ensureNotificationPermission() async => true;

  @override
  Future<void> show(BackgroundLabels labels, {required bool paused}) async {}

  @override
  Future<void> hide() async {}
}

/// Entry point of the foreground service isolate. It only forwards
/// notification button presses to the main isolate, where the recorder
/// lives, so capture never runs in two places.
@pragma('vm:entry-point')
void recordingTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_NotificationForwarder());
}

class _NotificationForwarder extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) =>
      FlutterForegroundTask.sendDataToMain(id);
}

/// Android implementation on top of `flutter_foreground_task`.
class AndroidRecordingBackground implements RecordingBackground {
  AndroidRecordingBackground() {
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  static const _serviceId = 4210;
  static const _pauseId = 'pause';
  static const _resumeId = 'resume';
  static const _stopId = 'stop';

  final _commands = StreamController<BackgroundCommand>.broadcast();
  bool _initialised = false;

  @override
  Stream<BackgroundCommand> get commands => _commands.stream;

  void _onData(Object data) {
    final command = switch (data) {
      _pauseId => BackgroundCommand.pause,
      _resumeId => BackgroundCommand.resume,
      _stopId => BackgroundCommand.stop,
      _ => null,
    };
    if (command != null) _commands.add(command);
  }

  @override
  Future<bool> ensureNotificationPermission() async {
    var status = await FlutterForegroundTask.checkNotificationPermission();
    if (status != NotificationPermission.granted) {
      status = await FlutterForegroundTask.requestNotificationPermission();
    }
    return status == NotificationPermission.granted;
  }

  void _init() {
    if (_initialised) return;
    _initialised = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'recording',
        channelName: 'Recording',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
      ),
    );
  }

  @override
  Future<void> show(BackgroundLabels labels, {required bool paused}) async {
    _init();
    final title = paused ? labels.pausedTitle : labels.title;
    final buttons = [
      NotificationButton(
        id: paused ? _resumeId : _pauseId,
        text: paused ? labels.resume : labels.pause,
      ),
      NotificationButton(id: _stopId, text: labels.stop),
    ];
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: '',
        notificationButtons: buttons,
      );
      return;
    }
    await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: [ForegroundServiceTypes.microphone],
      notificationTitle: title,
      notificationText: '',
      notificationButtons: buttons,
      callback: recordingTaskCallback,
    );
  }

  @override
  Future<void> hide() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}

/// The right implementation for this platform.
RecordingBackground createRecordingBackground() =>
    Platform.isAndroid ? AndroidRecordingBackground() : NoRecordingBackground();
