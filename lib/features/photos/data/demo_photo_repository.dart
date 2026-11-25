import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/features/photos/data/models.dart';
import 'package:family_stories/features/photos/data/photo_repository.dart';

/// DEMO MODE ONLY. In-memory photo list; "uploaded" images are kept as local
/// file paths so the UI shows the real picked image without any backend.
class DemoPhotoRepository implements PhotoRepository {
  /// [sampleImagePath] lets the web review build point photo-sample-1 at a
  /// real bundled fixture so image rendering is actually verified. On device
  /// demo the default points at nothing loadable and the thumbnail falls
  /// back to a plain frame.
  DemoPhotoRepository({String sampleImagePath = 'demo/sample-1.jpg'}) {
    // Visible sample content for review builds; clearly labeled, never real
    // family material.
    _photos.addAll([
      Photo(
        id: 'photo-sample-1',
        spaceId: 'demo-space',
        imagePath: sampleImagePath,
        caption: 'Wedding day (sample)',
        approxDateLabel: 'about 1970',
        visibility: PhotoVisibility.family,
        uploadedBy: 'demo-user',
        personIds: const ['p-sitto', 'p-giddu'],
      ),
      const Photo(
        id: 'photo-sample-2',
        spaceId: 'demo-space',
        imagePath: 'demo/sample-2.jpg',
        caption: 'The old house (sample)',
        approxDateLabel: 'about 1955',
        visibility: PhotoVisibility.family,
        uploadedBy: 'demo-user',
        personIds: ['p-sitto'],
      ),
      // PRIVATE and uploaded by someone else: the demo member must never see
      // it, only the locked link frame on a story that references it.
      const Photo(
        id: 'photo-sample-3',
        spaceId: 'demo-space',
        imagePath: 'demo/sample-3.jpg',
        caption: 'Private to someone else (sample)',
        approxDateLabel: 'about 1980',
        visibility: PhotoVisibility.private,
        uploadedBy: 'demo-user-2',
        personIds: ['p-giddu'],
      ),
    ]);
  }

  final List<Photo> _photos = [];
  var _seq = 0;

  @override
  Future<Result<List<Photo>>> listPhotos(String spaceId, {String? personId}) =>
      guard(() => _listPhotos(spaceId, personId: personId));

  @override
  Future<Result<String>> uploadImage(String localPath, String storagePath) =>
      guard(() => _uploadImage(localPath, storagePath));

  @override
  Future<Result<void>> deleteImage(String storagePath) =>
      guard(() => _deleteImage(storagePath));

  @override
  Future<Result<Photo>> createPhoto(Photo photo) =>
      guard(() => _createPhoto(photo));

  Future<List<Photo>> _listPhotos(String spaceId, {String? personId}) async {
    // Mirrors the RLS rule for the demo session: private photos are visible
    // only to their uploader; the demo session user is always 'demo-user'.
    var photos = _photos
        .where(
          (p) =>
              p.visibility == PhotoVisibility.family ||
              p.uploadedBy == 'demo-user',
        )
        .toList(growable: false);
    if (personId != null) {
      photos = photos.where((p) => p.personIds.contains(personId)).toList();
    }
    return photos;
  }

  Future<String> _uploadImage(String localPath, String storagePath) async =>
      localPath;

  Future<void> _deleteImage(String storagePath) async {}

  Future<Photo> _createPhoto(Photo photo) async {
    final p = Photo(
      id: 'photo-${_seq++}',
      spaceId: photo.spaceId,
      imagePath: photo.imagePath,
      caption: photo.caption,
      approxDateLabel: photo.approxDateLabel,
      visibility: photo.visibility,
      uploadedBy: photo.uploadedBy,
      personIds: photo.personIds,
    );
    _photos.add(p);
    return p;
  }

  @override
  // Local file path in demo mode; no signed URL needed.
  Future<Result<String>> createImageUrl(String imagePath) async =>
      Success(imagePath);
}
