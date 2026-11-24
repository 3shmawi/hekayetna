import 'dart:io';

import 'package:family_stories/features/recording/data/draft_store.dart';
import 'package:family_stories/features/recording/data/wav_repair.dart';
import 'package:family_stories/features/stories/data/models.dart';

/// Brings drafts back to a consistent state after the app was killed
/// mid-recording (spec 02, recovery on launch). Runs once at start-up.
class DraftRecovery {
  DraftRecovery(this._store, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DraftStore _store;
  final DateTime Function() _now;

  /// Marks every `recording` or `paused` draft `interrupted`, drops empty
  /// segments, repairs and re-measures WAV segments. Returns the recovered
  /// drafts, so the caller can log `recording_recovered`.
  Future<List<StoryDraft>> run() async {
    final recovered = <StoryDraft>[];
    for (final draft in await _store.list()) {
      if (draft.status != DraftStatus.recording &&
          draft.status != DraftStatus.paused) {
        continue;
      }
      final segments = <DraftSegment>[];
      for (final s in draft.segments) {
        final info = await WavRepair.repair(File(s.path));
        if (info == null) continue; // missing or empty: nothing to keep
        segments.add(s.copyWith(durationMs: info.durationMs, closed: true));
      }
      final fixed = draft.copyWith(
        segments: segments,
        status: DraftStatus.interrupted,
        updatedAt: _now(),
      );
      if (segments.isEmpty) {
        // Nothing audible survived: no point offering to continue it.
        await _store.delete(draft.id);
        continue;
      }
      await _store.save(fixed);
      recovered.add(fixed);
    }
    return recovered;
  }
}
