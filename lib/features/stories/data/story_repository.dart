import 'package:family_stories/features/stories/data/models.dart';

class StoryFilter {
  const StoryFilter({
    this.narratorId,
    this.topic,
    this.personId,
    this.yearFrom,
    this.yearTo,
  });
  final String? narratorId;
  final String? topic;
  final String? personId;
  final int? yearFrom;
  final int? yearTo;
}

abstract class StoryRepository {
  /// Only stories the signed-in member is authorized to access. Server-side
  /// RLS is the enforcement; the client never filters on the user's behalf.
  Future<List<Story>> listStories(String spaceId, {StoryFilter? filter});
  Future<Story?> getStory(String storyId);
  Future<Story> createStory(Story story);
  Future<Story> updateStory(Story story);
  Future<void> deleteStory(String storyId);
  Future<String> createAudioUrl(String audioPath); // short-lived signed URL

  /// Uploads a recorded file to the story-audio bucket at [storagePath]
  /// (`<space>/<uploader>/<story>/<file>.m4a`). Upload happens before the story row
  /// exists; the storage insert policy requires only space membership while
  /// reads require story access. Returns the storage path to persist.
  Future<String> uploadAudio(String localPath, String storagePath);

  /// Removes an uploaded object. Used when the story-row insert fails after a
  /// successful upload, so no orphan objects accumulate. Only the object's
  /// owner can delete, per the storage delete policy.
  Future<void> deleteAudio(String storagePath);
}
