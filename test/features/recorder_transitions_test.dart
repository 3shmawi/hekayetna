import 'package:family_stories/features/recording/data/recorder_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const idle = RecorderState(status: RecorderStatus.idle);

  test('start from idle begins recording bound to the draft', () {
    final s = RecorderTransitions.start(idle, 'd1');
    expect(s.status, RecorderStatus.recording);
    expect(s.draftId, 'd1');
  });

  test('pause and resume only work in their valid states', () {
    final rec = RecorderTransitions.start(idle, 'd1');
    expect(RecorderTransitions.pause(rec).status, RecorderStatus.paused);
    // pausing twice is a no-op, not an error
    final paused = RecorderTransitions.pause(rec);
    expect(RecorderTransitions.pause(paused).status, RecorderStatus.paused);
    expect(RecorderTransitions.resume(paused).status, RecorderStatus.recording);
    // resume from idle is rejected
    expect(RecorderTransitions.resume(idle).status, RecorderStatus.idle);
  });

  test('stop works from recording and paused, never from idle', () {
    final rec = RecorderTransitions.start(idle, 'd1');
    expect(RecorderTransitions.stop(rec).status, RecorderStatus.stopped);
    expect(
      RecorderTransitions.stop(RecorderTransitions.pause(rec)).status,
      RecorderStatus.stopped,
    );
    expect(RecorderTransitions.stop(idle).status, RecorderStatus.idle);
  });

  test('interruption pauses an active recording and keeps the take', () {
    final rec = RecorderTransitions.start(idle, 'd1');
    final interrupted = RecorderTransitions.interrupt(rec);
    expect(interrupted.status, RecorderStatus.paused);
    expect(interrupted.draftId, isNotNull);
    expect(interrupted.hasTake, isTrue);
  });

  test('double-tapping start while recording cannot corrupt state', () {
    final rec = RecorderTransitions.start(idle, 'd1');
    final again = RecorderTransitions.start(rec, 'd2');
    expect(again.status, RecorderStatus.recording);
    expect(again.draftId, 'd1');
  });

  test('discard always returns to idle', () {
    final rec = RecorderTransitions.start(idle, 'd1');
    expect(RecorderTransitions.discard(rec).status, RecorderStatus.idle);
  });
}
