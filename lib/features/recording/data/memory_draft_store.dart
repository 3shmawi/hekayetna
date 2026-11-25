import 'package:family_stories/features/recording/data/draft_store.dart';
import 'package:family_stories/features/stories/data/models.dart';

/// In-memory draft store for platforms without a filesystem (web preview).
/// Drafts vanish on reload; this exists so the UI can be reviewed in a
/// browser, never for production data.
class MemoryDraftStore implements DraftStore {
  final _drafts = <String, StoryDraft>{};
  final _segmentCounts = <String, int>{};

  @override
  Future<List<StoryDraft>> list() async =>
      _drafts.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Future<void> save(StoryDraft draft) async => _drafts[draft.id] = draft;

  @override
  Future<StoryDraft?> get(String id) async => _drafts[id];

  @override
  Future<void> delete(String id) async => _drafts.remove(id);

  @override
  Future<String> newSegmentPath(String draftId) async {
    final next = (_segmentCounts[draftId] ?? 0) + 1;
    _segmentCounts[draftId] = next;
    final index = next.toString().padLeft(3, '0');
    return 'memory://drafts/$draftId/seg-$index.wav';
  }
}
