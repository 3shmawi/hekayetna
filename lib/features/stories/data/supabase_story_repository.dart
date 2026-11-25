import 'dart:io';

import 'package:family_stories/core/network/result.dart';
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
  Future<Result<List<Story>>> listStories(
    String spaceId, {
    StoryFilter? filter,
  }) => guard(() => _listStories(spaceId, filter: filter));

  @override
  Future<Result<Story?>> getStory(String storyId) =>
      guard(() => _getStory(storyId));

  @override
  Future<Result<Story>> createStory(Story story) =>
      guard(() => _createStory(story));

  @override
  Future<Result<Story>> updateStory(Story story) =>
      guard(() => _updateStory(story));

  @override
  Future<Result<void>> deleteStory(String storyId) =>
      guard(() => _deleteStory(storyId));

  @override
  Future<Result<String>> createAudioUrl(String audioPath) =>
      guard(() => _createAudioUrl(audioPath));

  @override
  Future<Result<String>> uploadAudio(String localPath, String storagePath) =>
      guard(() => _uploadAudio(localPath, storagePath));

  @override
  Future<Result<void>> deleteAudio(String storagePath) =>
      guard(() => _deleteAudio(storagePath));

  Future<List<Story>> _listStories(
    String spaceId, {
    StoryFilter? filter,
  }) async {
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

  Future<Story?> _getStory(String storyId) async {
    final rows = await _client
        .from('stories')
        .select(_select)
        .eq('id', storyId)
        .limit(1);
    if ((rows as List).isEmpty) return null; // includes "not allowed to see it"
    return Story.fromJson(Map<String, dynamic>.from(rows[0] as Map));
  }

  Future<Story> _createStory(Story story) async {
    final values = <String, Object?>{
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
    };
    final waveform = story.waveform;
    Future<Map<String, dynamic>> insert(Map<String, Object?> v) =>
        _client.from('stories').insert(v).select().single();
    Map<String, dynamic> row;
    if (waveform == null) {
      row = await insert(values);
    } else {
      try {
        row = await insert({...values, 'waveform': waveform});
      } on PostgrestException catch (e) {
        // A backend that has not applied the waveform migration yet rejects
        // the whole insert (no row is created), so one retry without the
        // waveform cannot duplicate the story. The recording is kept; only
        // the optional waveform is left out. Any other error is real.
        if (!_isMissingWaveformColumn(e)) rethrow;
        row = await insert(values);
      }
    }
    final id = row['id'] as String;
    await _syncJoins(id, story);
    return (await _getStory(id))!;
  }

  /// PostgREST says PGRST204 ("Could not find the 'waveform' column ...") for
  /// an unknown column; Postgres itself says 42703 (undefined_column).
  static bool _isMissingWaveformColumn(PostgrestException e) {
    final mentionsWaveform = e.message.contains('waveform');
    return mentionsWaveform && (e.code == 'PGRST204' || e.code == '42703');
  }

  Future<Story> _updateStory(Story story) async {
    final before = await _getStory(story.id);
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
    return (await _getStory(story.id))!;
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

  Future<void> _deleteStory(String storyId) async {
    await _client.from('stories').delete().eq('id', storyId);
  }

  /// Short-lived signed URL (15 minutes). A signed URL stays usable until it
  /// expires even if access is revoked a second later; the short TTL is the
  /// mitigation, so do not raise it.
  Future<String> _createAudioUrl(String audioPath) =>
      _client.storage.from('story-audio').createSignedUrl(audioPath, 60 * 15);

  Future<String> _uploadAudio(String localPath, String storagePath) async {
    await _client.storage
        .from('story-audio')
        .upload(
          storagePath,
          File(localPath),
          fileOptions: FileOptions(
            contentType: localPath.endsWith('.wav') ? 'audio/wav' : 'audio/mp4',
          ),
        );
    return storagePath;
  }

  Future<void> _deleteAudio(String storagePath) async {
    await _client.storage.from('story-audio').remove([storagePath]);
  }
}
