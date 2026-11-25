import 'dart:async';

import 'package:family_stories/features/recording/data/memory_draft_store.dart';
import 'package:family_stories/features/recording/data/recorder_service.dart';
import 'package:family_stories/features/recording/data/recording_background.dart';
import 'package:family_stories/features/recording/data/recording_background_binder.dart';
import 'package:family_stories/features/recording/data/segmented_recorder_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'segmented_recorder_service_test.dart' show FakeSegmentRecorder;

class FakeBackground implements RecordingBackground {
  FakeBackground({this.permission = true});

  final bool permission;
  final controller = StreamController<BackgroundCommand>.broadcast();
  final log = <String>[];

  @override
  Stream<BackgroundCommand> get commands => controller.stream;

  @override
  Future<bool> ensureNotificationPermission() async {
    log.add('permission');
    return permission;
  }

  @override
  Future<void> show(BackgroundLabels labels, {required bool paused}) async =>
      log.add(paused ? 'paused' : 'recording');

  @override
  Future<void> hide() async => log.add('hide');
}

const _labels = BackgroundLabels(
  title: 't',
  pausedTitle: 'p',
  pause: 'pause',
  resume: 'resume',
  stop: 'stop',
);

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late SegmentedRecorderService service;
  late FakeBackground background;

  Future<RecordingBackgroundBinder> bind({bool permission = true}) async {
    service = SegmentedRecorderService(
      draftStore: MemoryDraftStore(),
      recorder: FakeSegmentRecorder(),
    );
    background = FakeBackground(permission: permission);
    return RecordingBackgroundBinder(
      recorder: service,
      background: background,
      labels: () => _labels,
    );
  }

  test('shows while recording, switches when paused, hides on stop', () async {
    final binder = await bind();
    await service.start(draftId: 'd1');
    await settle();
    await service.pause();
    await settle();
    await service.resume();
    await settle();
    await service.stop();
    await settle();
    expect(background.log, [
      'permission',
      'recording',
      'paused',
      'recording',
      'hide',
    ]);
    await binder.dispose();
    await service.dispose();
  });

  test('notification buttons drive the recorder', () async {
    final binder = await bind();
    await service.start(draftId: 'd1');
    background.controller.add(BackgroundCommand.pause);
    await settle();
    expect(service.state.status, RecorderStatus.paused);
    background.controller.add(BackgroundCommand.resume);
    await settle();
    expect(service.state.status, RecorderStatus.recording);
    background.controller.add(BackgroundCommand.stop);
    await settle();
    expect(service.state.status, RecorderStatus.stopped);
    await binder.dispose();
    await service.dispose();
  });

  test(
    'denied notification permission: no service, recording goes on',
    () async {
      final binder = await bind(permission: false);
      await service.start(draftId: 'd1');
      await settle();
      expect(service.state.status, RecorderStatus.recording);
      expect(binder.notificationsDenied, isTrue);
      expect(background.log, ['permission']);
      await binder.dispose();
      await service.dispose();
    },
  );
}
