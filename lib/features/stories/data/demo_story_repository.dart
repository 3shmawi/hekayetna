import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/data/story_repository.dart';

/// DEMO MODE ONLY. In-memory stories with realistic sample content. Demo data
/// is visibly labeled in the UI and never presented as backend data.
class DemoStoryRepository implements StoryRepository {
  DemoStoryRepository() {
    _stories.add(
      Story(
        id: 's-om-ali',
        spaceId: 'demo-space',
        title: 'The first Om Ali (sample)',
        description: 'How Sitto learned to make Om Ali from her mother.',
        topic: 'ramadan_eid_traditions',
        approxDateLabel: 'Ramadan, late 1950s',
        approxYear: 1958,
        visibility: StoryVisibility.family,
        audioPath: 'demo/om-ali.m4a',
        durationSeconds: 154,
        createdBy: 'demo-user',
        createdAt: DateTime(2026, 11, 20),
        narratorIds: const ['p-sitto'],
        peopleIds: const ['p-sitto', 'p-giddu'],
        // One accessible family photo (renders) and one private photo owned by
        // someone else (locked frame): the grid shows both states honestly.
        photoIds: const ['photo-sample-1', 'photo-sample-3'],
      ),
    );
  }

  final List<Story> _stories = [];
  var _seq = 0;

  @override
  Future<List<Story>> listStories(String spaceId, {StoryFilter? filter}) async {
    var all = List<Story>.from(_stories);
    final f = filter;
    if (f?.narratorId != null) {
      all = all.where((s) => s.narratorIds.contains(f!.narratorId)).toList();
    }
    if (f?.topic != null) all = all.where((s) => s.topic == f!.topic).toList();
    if (f?.personId != null) {
      all = all.where((s) => s.peopleIds.contains(f!.personId)).toList();
    }
    if (f?.yearFrom != null) {
      all = all.where((s) => (s.approxYear ?? 0) >= f!.yearFrom!).toList();
    }
    if (f?.yearTo != null) {
      all = all.where((s) => (s.approxYear ?? 9999) <= f!.yearTo!).toList();
    }
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  @override
  Future<Story?> getStory(String storyId) async {
    for (final s in _stories) {
      if (s.id == storyId) return s;
    }
    return null;
  }

  @override
  Future<Story> createStory(Story story) async {
    final s = Story(
      id: 's-${_seq++}',
      spaceId: story.spaceId,
      title: story.title,
      description: story.description,
      topic: story.topic,
      approxDateLabel: story.approxDateLabel,
      approxYear: story.approxYear,
      visibility: story.visibility, // default is always private, set by caller
      audioPath: story.audioPath,
      durationSeconds: story.durationSeconds,
      createdBy: story.createdBy,
      createdAt: DateTime.now(),
      narratorIds: story.narratorIds,
      peopleIds: story.peopleIds,
      photoIds: story.photoIds,
      recipientUserIds: story.recipientUserIds,
    );
    _stories.add(s);
    return s;
  }

  @override
  Future<Story> updateStory(Story story) async {
    final i = _stories.indexWhere((s) => s.id == story.id);
    if (i < 0) throw StateError('not_found');
    _stories[i] = story;
    return story;
  }

  @override
  Future<void> deleteStory(String storyId) async {
    _stories.removeWhere((s) => s.id == storyId);
  }

  @override
  Future<String> createAudioUrl(String audioPath) async =>
      'demo://audio/$audioPath';

  @override
  Future<String> uploadAudio(String localPath, String storagePath) async =>
      storagePath;

  @override
  Future<void> deleteAudio(String storagePath) async {}
}
