import 'package:family_stories/features/photos/data/models.dart';

abstract class PhotoRepository {
  /// Only photos the signed-in member is authorized to see (RLS enforces).
  Future<List<Photo>> listPhotos(String spaceId, {String? personId});

  /// Uploads an image to family-photos at [storagePath]
  /// (`<space>/<uploader>/<photo>/<file>`), before the photo row exists.
  Future<String> uploadImage(String localPath, String storagePath);

  /// Removes an uploaded object when the photo-row insert fails afterwards,
  /// so failed saves leave no orphan objects.
  Future<void> deleteImage(String storagePath);

  Future<Photo> createPhoto(Photo photo);

  /// Short-lived signed URL (15 minutes). A signed URL stays usable until it
  /// expires even if access is revoked a second later; the short TTL is the
  /// mitigation, so do not raise it.
  Future<String> createImageUrl(String imagePath);
}
