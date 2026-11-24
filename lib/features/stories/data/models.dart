/// Story domain models. The audio recording is the source of truth; any
/// future AI-derived content lives separately and never replaces it.
enum StoryVisibility { private, selected, family }

class Story {
  const Story({
    required this.id,
    required this.spaceId,
    required this.title,
    required this.visibility,
    required this.audioPath,
    required this.durationSeconds,
    required this.createdBy,
    required this.createdAt,
    this.description,
    this.topic,
    this.approxDateLabel,
    this.approxYear,
    this.narratorIds = const [],
    this.peopleIds = const [],
    this.photoIds = const [],
    this.recipientUserIds = const [],
  });

  factory Story.fromJson(Map<String, dynamic> j) => Story(
    id: j['id'] as String,
    spaceId: j['space_id'] as String,
    title: j['title'] as String,
    description: j['description'] as String?,
    topic: j['topic'] as String?,
    approxDateLabel: j['approx_date_label'] as String?,
    approxYear: j['approx_year'] as int?,
    visibility: StoryVisibility.values.byName(j['visibility'] as String),
    audioPath: j['audio_path'] as String,
    durationSeconds: (j['duration_seconds'] as num?)?.toInt() ?? 0,
    createdBy: j['created_by'] as String,
    createdAt: DateTime.parse(j['created_at'] as String),
    narratorIds: [
      for (final r
          in (j['story_narrators'] as List? ?? []).cast<Map<String, dynamic>>())
        r['person_id'] as String,
    ],
    peopleIds: [
      for (final r
          in (j['story_people'] as List? ?? []).cast<Map<String, dynamic>>())
        r['person_id'] as String,
    ],
    photoIds: [
      for (final r
          in (j['story_photos'] as List? ?? []).cast<Map<String, dynamic>>())
        r['photo_id'] as String,
    ],
    recipientUserIds: [
      for (final r
          in (j['story_recipients'] as List? ?? [])
              .cast<Map<String, dynamic>>())
        r['grantee_user_id'] as String,
    ],
  );

  final String id;
  final String spaceId;
  final String title;
  final String? description;
  final String? topic; // stable key from kStoryTopics, null = free story
  final String? approxDateLabel;
  final int? approxYear;
  final StoryVisibility visibility;
  final String audioPath;
  final int durationSeconds;
  final String createdBy;
  final DateTime createdAt;
  final List<String> narratorIds;
  final List<String> peopleIds;
  final List<String> photoIds;
  final List<String> recipientUserIds;
}

/// A recording that has not become a story yet. Drafts are always private
/// and live on-device until the user saves (uploads) them.
class StoryDraft {
  const StoryDraft({
    required this.id,
    required this.filePath,
    required this.durationSeconds,
    required this.updatedAt,
    this.narratorPersonId,
    this.topic,
  });

  factory StoryDraft.fromJson(Map<String, dynamic> j) => StoryDraft(
    id: j['id'] as String,
    filePath: j['filePath'] as String,
    narratorPersonId: j['narratorPersonId'] as String?,
    topic: j['topic'] as String?,
    durationSeconds: (j['durationSeconds'] as num).toInt(),
    updatedAt: DateTime.parse(j['updatedAt'] as String),
  );

  final String id;
  final String filePath;
  final String? narratorPersonId;
  final String? topic;
  final int durationSeconds;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'filePath': filePath,
    'narratorPersonId': narratorPersonId,
    'topic': topic,
    'durationSeconds': durationSeconds,
    'updatedAt': updatedAt.toIso8601String(),
  };
}
