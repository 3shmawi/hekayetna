import 'package:family_stories/features/stories/data/models.dart';

/// Recording state machine. The states are deliberately few and every
/// transition is explicit, so interruption behavior is testable without a
/// microphone: idle -> recording <-> paused -> stopped -> idle.
/// Any state can move to failed; from failed the partial take is kept and
/// the user returns to idle with the draft preserved.
enum RecorderStatus { idle, recording, paused, stopped, failed }

class RecorderState {
  const RecorderState({
    required this.status,
    this.draftId,
    this.segments = const [],
    this.elapsed = Duration.zero,
    this.error,
  });

  final RecorderStatus status;

  /// The draft this take is written into; set from the first start.
  final String? draftId;

  /// Segment files of the take so far; the last one may still be open.
  final List<DraftSegment> segments;

  /// Total take duration across closed segments plus the open one.
  final Duration elapsed;
  final String? error;

  bool get canPause => status == RecorderStatus.recording;
  bool get canResume => status == RecorderStatus.paused;
  bool get canStop =>
      status == RecorderStatus.recording || status == RecorderStatus.paused;
  bool get hasTake =>
      draftId != null &&
      (status == RecorderStatus.stopped || status == RecorderStatus.paused);

  RecorderState copyWith({
    RecorderStatus? status,
    String? draftId,
    List<DraftSegment>? segments,
    Duration? elapsed,
    String? error,
  }) => RecorderState(
    status: status ?? this.status,
    draftId: draftId ?? this.draftId,
    segments: segments ?? this.segments,
    elapsed: elapsed ?? this.elapsed,
    error: error,
  );
}

/// Transition rules, pure and unit-tested. Invalid transitions are rejected
/// so a double-tap or an interruption callback can never corrupt state.
class RecorderTransitions {
  const RecorderTransitions._();

  static RecorderState start(RecorderState s, String draftId) {
    if (s.status != RecorderStatus.idle && s.status != RecorderStatus.failed) {
      return s;
    }
    return RecorderState(status: RecorderStatus.recording, draftId: draftId);
  }

  static RecorderState pause(RecorderState s) =>
      s.canPause ? s.copyWith(status: RecorderStatus.paused) : s;

  static RecorderState resume(RecorderState s) =>
      s.canResume ? s.copyWith(status: RecorderStatus.recording) : s;

  static RecorderState stop(RecorderState s) =>
      s.canStop ? s.copyWith(status: RecorderStatus.stopped) : s;

  /// Interruption (phone call, app backgrounded by OS): recording pauses,
  /// the partial take stays on disk, and the draft index keeps pointing at it.
  static RecorderState interrupt(RecorderState s) =>
      s.status == RecorderStatus.recording
      ? s.copyWith(status: RecorderStatus.paused)
      : s;

  static RecorderState fail(RecorderState s, String error) =>
      s.copyWith(status: RecorderStatus.failed, error: error);

  static RecorderState discard(RecorderState s) =>
      const RecorderState(status: RecorderStatus.idle);
}

abstract class RecorderService {
  RecorderState get state;
  Stream<RecorderState> watch();
  Future<bool> ensurePermission();

  /// Starts a new take into draft [draftId]: reserves the first segment
  /// path, writes the draft to the index BEFORE the recorder starts (AC-1),
  /// then begins capture.
  Future<void> start({
    required String draftId,
    String? narratorPersonId,
    String? topic,
    String? promptId,
  });
  Future<void> pause();
  Future<void> resume();

  /// Finishes the take: the open segment is closed and the draft is marked
  /// finished in the index.
  Future<void> stop();
  Future<void> discard();
  Future<void> dispose();
}
