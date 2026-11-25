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
    this.waveform,
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
    waveform: (j['waveform'] as List?)?.map((v) => (v as num).toInt()).toList(),
  );

  Story copyWith({
    String? title,
    String? Function()? description,
    String? Function()? approxDateLabel,
    StoryVisibility? visibility,
  }) => Story(
    id: id,
    spaceId: spaceId,
    title: title ?? this.title,
    description: description == null ? this.description : description(),
    topic: topic,
    approxDateLabel: approxDateLabel == null
        ? this.approxDateLabel
        : approxDateLabel(),
    approxYear: approxYear,
    visibility: visibility ?? this.visibility,
    audioPath: audioPath,
    durationSeconds: durationSeconds,
    createdBy: createdBy,
    createdAt: createdAt,
    narratorIds: narratorIds,
    peopleIds: peopleIds,
    photoIds: photoIds,
    recipientUserIds: recipientUserIds,
    waveform: waveform,
  );

  /// 0 to 100 per bar (64 bars when recorded with spec 04); null on older
  /// stories.
  final List<int>? waveform;

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

/// Lifecycle of a recording draft (spec 02). `finished` means the user
/// stopped the take; the other three describe a take that can still grow.
enum DraftStatus { recording, paused, interrupted, finished }

/// One audio file of a take. A new segment starts on record, on every
/// resume and on rotation, so a kill or crash never costs more than the
/// open segment. [closed] marks a segment the recorder finished writing;
/// an open (`closed == false`) segment may be truncated by a kill and is
/// re-measured during recovery.
class DraftSegment {
  const DraftSegment({
    required this.path,
    required this.durationMs,
    this.closed = false,
  });

  factory DraftSegment.fromJson(Map<String, dynamic> j) => DraftSegment(
    path: j['path'] as String,
    durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
    closed: j['closed'] as bool? ?? false,
  );

  final String path;
  final int durationMs;
  final bool closed;

  DraftSegment copyWith({int? durationMs, bool? closed}) => DraftSegment(
    path: path,
    durationMs: durationMs ?? this.durationMs,
    closed: closed ?? this.closed,
  );

  Map<String, dynamic> toJson() => {
    'path': path,
    'durationMs': durationMs,
    'closed': closed,
  };
}

/// A recording that has not become a story yet. Drafts are always private
/// and live on-device until the user saves (uploads) them.
///
/// Since spec 02 a draft is a list of [segments]. The JSON stays backward
/// compatible: drafts written before spec 02 (single `filePath` +
/// `durationSeconds`) load as one closed [DraftSegment] with status
/// [DraftStatus.finished], and [toJson] still writes the legacy fields so a
/// pre-spec-02 build can read new drafts. The legacy constructor shape
/// (`filePath` + `durationSeconds`) keeps working and builds one finished
/// closed segment.
class StoryDraft {
  StoryDraft({
    required this.id,
    required this.updatedAt,
    String? filePath,
    int? durationSeconds,
    List<DraftSegment>? segments,
    DraftStatus? status,
    this.narratorPersonId,
    this.topic,
    this.promptId,
    DateTime? createdAt,
  }) : segments =
           segments ??
           (filePath != null
               ? [
                   DraftSegment(
                     path: filePath,
                     durationMs: (durationSeconds ?? 0) * 1000,
                     closed: true,
                   ),
                 ]
               : const <DraftSegment>[]),
       status =
           status ??
           (filePath != null && segments == null
               ? DraftStatus.finished
               : DraftStatus.recording),
       createdAt = createdAt ?? updatedAt;

  factory StoryDraft.fromJson(Map<String, dynamic> j) {
    final rawSegments = j['segments'] as List?;
    return StoryDraft(
      id: j['id'] as String,
      // Legacy single-file fields; ignored when `segments` is present.
      filePath: j['filePath'] as String?,
      durationSeconds: (j['durationSeconds'] as num?)?.toInt(),
      segments: rawSegments == null
          ? null
          : [
              for (final s in rawSegments)
                DraftSegment.fromJson(Map<String, dynamic>.from(s as Map)),
            ],
      status: j['status'] != null
          ? DraftStatus.values.byName(j['status'] as String)
          : null,
      narratorPersonId: j['narratorPersonId'] as String?,
      topic: j['topic'] as String?,
      promptId: j['promptId'] as String?,
      createdAt: j['createdAt'] != null
          ? DateTime.parse(j['createdAt'] as String)
          : null,
      updatedAt: DateTime.parse(j['updatedAt'] as String),
    );
  }

  final String id;
  final List<DraftSegment> segments;
  final DraftStatus status;
  final String? narratorPersonId;
  final String? topic;
  final String? promptId;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Total kept duration across all segments.
  Duration get duration => segments.fold(
    Duration.zero,
    (sum, s) => sum + Duration(milliseconds: s.durationMs),
  );

  /// Legacy single-file view: the first segment's path, or '' when the take
  /// has no segments yet. New code should use [segments].
  String get filePath => segments.isEmpty ? '' : segments.first.path;

  /// Legacy whole-seconds view of [duration].
  int get durationSeconds => duration.inSeconds;

  StoryDraft copyWith({
    List<DraftSegment>? segments,
    DraftStatus? status,
    String? narratorPersonId,
    String? topic,
    String? promptId,
    DateTime? updatedAt,
  }) => StoryDraft(
    id: id,
    segments: segments ?? this.segments,
    status: status ?? this.status,
    narratorPersonId: narratorPersonId ?? this.narratorPersonId,
    topic: topic ?? this.topic,
    promptId: promptId ?? this.promptId,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status.name,
    'segments': [for (final s in segments) s.toJson()],
    'narratorPersonId': narratorPersonId,
    'topic': topic,
    'promptId': promptId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    // Legacy fields, so a pre-spec-02 build can still read new drafts.
    'filePath': filePath,
    'durationSeconds': durationSeconds,
  };
}
