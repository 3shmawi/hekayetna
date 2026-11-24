import 'package:family_stories/features/stories/data/models.dart';

/// On-device index of recording drafts. Drafts are private by construction:
/// they never leave the device until the user explicitly saves a story.
abstract class DraftStore {
  Future<List<StoryDraft>> list();
  Future<void> save(StoryDraft draft);
  Future<StoryDraft?> get(String id);
  Future<void> delete(String id);
}
