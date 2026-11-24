import 'dart:io';

import 'package:family_stories/features/photos/data/models.dart';
import 'package:family_stories/features/photos/data/photo_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Live backend implementation. Access rules are enforced by RLS and the
/// storage policies, not by this client.
class SupabasePhotoRepository implements PhotoRepository {
  SupabasePhotoRepository(this._client);
  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  static const _select = '*, photo_people(person_id)';

  @override
  Future<List<Photo>> listPhotos(String spaceId, {String? personId}) async {
    final rows = await _client
        .from('photos')
        .select(_select)
        .eq('space_id', spaceId);
    var photos = [
      for (final r in rows as List)
        Photo.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
    if (personId != null) {
      photos = photos.where((p) => p.personIds.contains(personId)).toList();
    }
    return photos;
  }

  @override
  Future<String> uploadImage(String localPath, String storagePath) async {
    await _client.storage
        .from('family-photos')
        .upload(storagePath, File(localPath));
    return storagePath;
  }

  @override
  Future<void> deleteImage(String storagePath) async {
    await _client.storage.from('family-photos').remove([storagePath]);
  }

  @override
  Future<Photo> createPhoto(Photo photo) async {
    final row = await _client
        .from('photos')
        .insert({
          if (photo.id.isNotEmpty) 'id': photo.id,
          'space_id': photo.spaceId,
          'image_path': photo.imagePath,
          'caption': photo.caption,
          'approx_date_label': photo.approxDateLabel,
          'visibility': photo.visibility.name,
          'uploaded_by': _uid,
        })
        .select()
        .single();
    final id = row['id'] as String;
    if (photo.personIds.isNotEmpty) {
      await _client.from('photo_people').insert([
        for (final p in photo.personIds) {'photo_id': id, 'person_id': p},
      ]);
    }
    final rows = await _client
        .from('photos')
        .select(_select)
        .eq('id', id)
        .limit(1);
    return Photo.fromJson(
      Map<String, dynamic>.from((rows as List).first as Map),
    );
  }

  @override
  Future<String> createImageUrl(String imagePath) =>
      _client.storage.from('family-photos').createSignedUrl(imagePath, 60 * 15);
}
