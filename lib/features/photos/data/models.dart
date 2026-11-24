/// Photo domain model. Photo permissions are fully independent of stories:
/// linking a photo to a story never widens its audience (see
/// docs/database-design.md).
enum PhotoVisibility { private, family }

class Photo {
  const Photo({
    required this.id,
    required this.spaceId,
    required this.imagePath,
    required this.visibility,
    required this.uploadedBy,
    this.caption,
    this.approxDateLabel,
    this.personIds = const [],
  });

  factory Photo.fromJson(Map<String, dynamic> j) => Photo(
    id: j['id'] as String,
    spaceId: j['space_id'] as String,
    imagePath: j['image_path'] as String,
    caption: j['caption'] as String?,
    approxDateLabel: j['approx_date_label'] as String?,
    visibility: PhotoVisibility.values.byName(j['visibility'] as String),
    uploadedBy: j['uploaded_by'] as String,
    personIds: [
      for (final r
          in (j['photo_people'] as List? ?? []).cast<Map<String, dynamic>>())
        r['person_id'] as String,
    ],
  );

  final String id;
  final String spaceId;
  final String imagePath;
  final String? caption;
  final String? approxDateLabel;
  final PhotoVisibility visibility;
  final String uploadedBy;
  final List<String> personIds;
}
