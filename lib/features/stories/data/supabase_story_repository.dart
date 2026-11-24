import 'dart:io';

import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/data/story_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Live backend implementation. Row-level security decides what rows come
/// back; this client asks plainly and never filters on the user's behalf.
class SupabaseStoryRepository implements StoryRepository {
  SupabaseStoryRepository(this._client);
  final SupabaseClient _client;

  static const _select =
      '*, story_narrators(person_id), story_people(person_id), '
      'story_photos(photo_id), story_recipients(grantee_user_id)';

  String get _uid => _client.auth.currentUser!.id;

  @override
  Future<List<Story>> listStories(String spaceId, {StoryFilter? filter}) async {
    var q = _client.from('stories').select(_select).eq('space_id', spaceId);
    final f = filter;
    if (f?.topic != null) q = q.eq('topic', f!.topic!);
    if (f?.yearFrom != null) q = q.gte('approx_year', f!.yearFrom!);
    if (f?.yearTo != null) q = q.lte('approx_year', f!.yearTo!);
    final rows = await q.order('created_at', ascending: false);
    var stories = [
      for (final r in rows as List)
        Story.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
    if (f?.narratorId != null) {
      stories = stories
          .where((s) => s.narratorIds.contains(f!.narratorId))
          .toList();
    }
    if (f?.personId != null) {
      stories = stories
          .where((s) => s.peopleIds.contains(f!.personId))
          .toList();
    }
    return stories;
  }

  @override
  Future<Story?> getStory(String storyId) async {
    final rows = await _client
        .from('stories')
        .select(_select)
        .eq('id', storyId)
        .limit(1);
    if ((rows as List).isEmpty) return null; // includes "not allowed to see it"
    return Story.fromJson(Map<String, dynamic>.from(rows[0] as Map));
  }

  @override
  Future<Story> createStory(Story story) async {
    final row = await _client
        .from('stories')
        .insert({
          if (story.id.isNotEmpty) 'id': story.id,
          'space_id': story.spaceId,
          'title': story.title,
          'description': story.description,
          'topic': story.topic,
          'approx_date_label': story.approxDateLabel,
          'approx_year': story.approxYear,
          'visibility': story.visibility.name,
          'audio_path': story.audioPath,
          'duration_seconds': story.durationSeconds,
          'created_by': _uid,
        })
        .select()
        .single();
    final id = row['id'] as String;
    await _syncJoins(id, story);
    return (await getStory(id))!;
  }

  @override
  Future<Story> updateStory(Story story) async {
    final before = await getStory(story.id);
    final visibilityChanged = before?.visibility != story.visibility;
    // Old grants go first, so removing someone from a "selected" story or
    // making a shared story private takes their access away. A family story
    // that stays a family story keeps its snapshot: re-saving it must not
    // share it with members who joined after it was shared.
    if (visibilityChanged || story.visibility == StoryVisibility.selected) {
      await _client.from('story_recipients').delete().eq('story_id', story.id);
    }
    await _client
        .from('stories')
        .update({
          'title': story.title,
          'description': story.description,
          'topic': story.topic,
          'approx_date_label': story.approxDateLabel,
          'approx_year': story.approxYear,
          // Only when it changes: setting it fires the family-share
          // snapshot trigger (migration 0003).
          if (visibilityChanged) 'visibility': story.visibility.name,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', story.id);
    await _client.from('story_narrators').delete().eq('story_id', story.id);
    await _client.from('story_people').delete().eq('story_id', story.id);
    await _client.from('story_photos').delete().eq('story_id', story.id);
    await _syncJoins(story.id, story);
    return (await getStory(story.id))!;
  }

  Future<void> _syncJoins(String storyId, Story story) async {
    if (story.narratorIds.isNotEmpty) {
      await _client.from('story_narrators').insert([
        for (var i = 0; i < story.narratorIds.length; i++)
          {
            'story_id': storyId,
            'person_id': story.narratorIds[i],
            'position': i,
          },
      ]);
    }
    if (story.peopleIds.isNotEmpty) {
      await _client.from('story_people').insert([
        for (final p in story.peopleIds) {'story_id': storyId, 'person_id': p},
      ]);
    }
    if (story.photoIds.isNotEmpty) {
      await _client.from('story_photos').insert([
        for (final p in story.photoIds) {'story_id': storyId, 'photo_id': p},
      ]);
    }
    if (story.visibility == StoryVisibility.selected &&
        story.recipientUserIds.isNotEmpty) {
      await _client.from('story_recipients').insert([
        for (final u in story.recipientUserIds)
          {'story_id': storyId, 'grantee_user_id': u, 'granted_by': _uid},
      ]);
    }
  }

  @override
  Future<void> deleteStory(String storyId) async {
    await _client.from('stories').delete().eq('id', storyId);
  }

  /// Short-lived signed URL (15 minutes). A signed URL stays usable until it
  /// expires even if access is revoked a second later; the short TTL is the
  /// mitigation, so do not raise it.
  @override
  Future<String> createAudioUrl(String audioPath) =>
      _client.storage.from('story-audio').createSignedUrl(audioPath, 60 * 15);

  @override
  Future<String> uploadAudio(String localPath, String storagePath) async {
    await _client.storage
        .from('story-audio')
        .upload(
          storagePath,
          File(localPath),
          fileOptions: const FileOptions(contentType: 'audio/mp4'),
        );
    return storagePath;
  }

  @override
  Future<void> deleteAudio(String storagePath) async {
    await _client.storage.from('story-audio').remove([storagePath]);
  }
}
