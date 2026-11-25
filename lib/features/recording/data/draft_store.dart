import 'package:family_stories/features/stories/data/models.dart';

/// On-device index of recording drafts. Drafts are private by construction:
/// they never leave the device until the user explicitly saves a story.
abstract class DraftStore {
  Future<List<StoryDraft>> list();
  Future<void> save(StoryDraft draft);
  Future<StoryDraft?> get(String id);
  Future<void> delete(String id);

  /// Reserves the path for the next audio segment of [draftId], creating
  /// the draft's directory if needed. The store owns every file location;
  /// callers never build paths themselves.
  Future<String> newSegmentPath(String draftId);
}
