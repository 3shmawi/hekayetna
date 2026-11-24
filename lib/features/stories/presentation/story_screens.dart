import 'dart:async';
import 'dart:io';

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/ids.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/core/theme/app_colors.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/photos/data/models.dart';
import 'package:family_stories/features/recording/data/segment_joiner.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/domain/story_topics.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class StoryPhotosGrid extends ConsumerWidget {
  const StoryPhotosGrid({required this.photoIds, super.key});
  final List<String> photoIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(isDemoModeProvider);
    return FutureBuilder<List<Photo>>(
      future: ref
          .read(familyRepositoryProvider)
          .getMySpace()
          .unwrap()
          .then(
            (space) => space == null
                ? <Photo>[]
                : ref
                      .read(photoRepositoryProvider)
                      .listPhotos(space.id)
                      .unwrap(),
          ),
      builder: (context, snap) {
        final visible = (snap.data ?? const <Photo>[])
            .where((p) => photoIds.contains(p.id))
            .toList();
        return GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            // One frame per LINKED photo, even when the photo itself is not
            // accessible: the link is story metadata, the image is not.
            for (final id in photoIds)
              if (visible.any((p) => p.id == id))
                _StoryPhotoThumb(
                  photo: visible.firstWhere((p) => p.id == id),
                  demo: demo,
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.sand,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.inkSoft),
                  ),
                  child: const Center(
                    child: Icon(Icons.lock_outline, color: AppColors.inkSoft),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _StoryPhotoThumb extends ConsumerWidget {
  const _StoryPhotoThumb({required this.photo, required this.demo});
  final Photo photo;
  final bool demo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (demo) {
      // dart:io File is unsupported on web preview builds: show the plain
      // sample frame there instead of throwing before errorBuilder can run.
      if (kIsWeb) {
        // A real URL (the bundled synthetic fixture) renders for real, so
        // review builds verify image display; anything else gets the frame.
        if (photo.imagePath.startsWith('http')) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              photo.imagePath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) =>
                  const ColoredBox(color: AppColors.sand),
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: const ColoredBox(
            color: AppColors.sand,
            child: Center(
              child: Icon(Icons.photo_outlined, color: AppColors.inkSoft),
            ),
          ),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(photo.imagePath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) =>
              const ColoredBox(color: AppColors.sand),
        ),
      );
    }
    return FutureBuilder<String>(
      future: ref
          .read(photoRepositoryProvider)
          .createImageUrl(photo.imagePath)
          .unwrap(),
      builder: (context, snap) {
        final url = snap.data;
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: url == null
              ? const ColoredBox(color: AppColors.sand)
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) =>
                      const ColoredBox(color: AppColors.sand),
                ),
        );
      },
    );
  }
}

/// Create or edit a story from a recording draft. The visibility picker is
/// always visible before saving, with its consequence in plain words.
class StoryEditScreen extends ConsumerStatefulWidget {
  const StoryEditScreen({super.key, this.draftId});
  final String? draftId;

  @override
  ConsumerState<StoryEditScreen> createState() => _StoryEditScreenState();
}

class _StoryEditScreenState extends ConsumerState<StoryEditScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _approxDate = TextEditingController();
  String? _topic;
  StoryVisibility _visibility =
      StoryVisibility.private; // default is always private
  bool _busy = false;
  final Set<String> _narratorIds = {};
  final Set<String> _peopleIds = {};
  final Set<String> _recipientUserIds = {};
  final Set<String> _photoIds = {};
  bool _seeded = false;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(s.recordAStory)),
      body: FutureBuilder<StoryDraft?>(
        future: widget.draftId == null
            ? Future.value()
            : ref.read(draftStoreProvider).get(widget.draftId!),
        builder: (context, draftSnap) {
          final draft = draftSnap.data;
          if (!_seeded && draft?.narratorPersonId != null) {
            _narratorIds.add(draft!.narratorPersonId!);
            _seeded = true;
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextField(
                controller: _title,
                decoration: InputDecoration(labelText: s.storyTitle),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                maxLines: 3,
                decoration: InputDecoration(labelText: s.description),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _approxDate,
                decoration: InputDecoration(labelText: s.approxDate),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _topic ?? draft?.topic,
                decoration: InputDecoration(labelText: s.topic),
                items: [
                  DropdownMenuItem(child: Text(s.noTopic)),
                  for (final t in kStoryTopics)
                    DropdownMenuItem(value: t, child: Text(topicLabel(s, t))),
                ],
                onChanged: (v) => setState(() => _topic = v),
              ),
              const SizedBox(height: 16),
              // Narrators and mentioned people. A story may have several
              // narrators; each stays identifiable (stored with position).
              FutureBuilder<List<Person>>(
                future: ref
                    .read(familyRepositoryProvider)
                    .getMySpace()
                    .unwrap()
                    .then(
                      (space) => space == null
                          ? <Person>[]
                          : ref
                                .read(familyRepositoryProvider)
                                .listPersons(space.id)
                                .unwrap(),
                    ),
                builder: (context, snap) {
                  final persons = snap.data ?? const <Person>[];
                  if (persons.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        s.narrators,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final p in persons)
                            FilterChip(
                              label: Text(p.fullName),
                              selected: _narratorIds.contains(p.id),
                              onSelected: (on) => setState(
                                () => on
                                    ? _narratorIds.add(p.id)
                                    : _narratorIds.remove(p.id),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        s.peopleMentioned,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final p in persons)
                            FilterChip(
                              label: Text(p.fullName),
                              selected: _peopleIds.contains(p.id),
                              onSelected: (on) => setState(
                                () => on
                                    ? _peopleIds.add(p.id)
                                    : _peopleIds.remove(p.id),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              // Linking a photo never widens the photo's audience: photo
              // access is checked independently (see docs/database-design.md).
              // Only photos the member can already see are listed here.
              FutureBuilder<List<Photo>>(
                future: ref
                    .read(familyRepositoryProvider)
                    .getMySpace()
                    .unwrap()
                    .then(
                      (space) => space == null
                          ? <Photo>[]
                          : ref
                                .read(photoRepositoryProvider)
                                .listPhotos(space.id)
                                .unwrap(),
                    ),
                builder: (context, snap) {
                  final photos = snap.data ?? const <Photo>[];
                  if (photos.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        s.linkPhotos,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final p in photos)
                            FilterChip(
                              avatar: _photoIds.contains(p.id)
                                  ? const Icon(Icons.check, size: 18)
                                  : null,
                              label: Text(
                                p.caption ??
                                    p.approxDateLabel ??
                                    p.id.substring(0, 8),
                              ),
                              selected: _photoIds.contains(p.id),
                              onSelected: (on) => setState(
                                () => on
                                    ? _photoIds.add(p.id)
                                    : _photoIds.remove(p.id),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                s.whoCanHear,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              RadioGroup<StoryVisibility>(
                groupValue: _visibility,
                onChanged: (x) => setState(() => _visibility = x!),
                child: Column(
                  children: [
                    for (final v in StoryVisibility.values)
                      RadioListTile<StoryVisibility>(
                        value: v,
                        title: Text(switch (v) {
                          StoryVisibility.private => s.visPrivate,
                          StoryVisibility.selected => s.visSelected,
                          StoryVisibility.family => s.visFamily,
                        }),
                        subtitle: Text(switch (v) {
                          StoryVisibility.private => s.visPrivateDesc,
                          StoryVisibility.selected => s.visSelectedDesc,
                          StoryVisibility.family => s.visFamilyDesc,
                        }),
                      ),
                  ],
                ),
              ),
              // Recipient picker: without it a "selected people" story would
              // grant nobody. Only members of the space can be picked.
              if (_visibility == StoryVisibility.selected)
                FutureBuilder<List<FamilyMember>>(
                  future: ref
                      .read(familyRepositoryProvider)
                      .getMySpace()
                      .unwrap()
                      .then(
                        (space) => space == null
                            ? <FamilyMember>[]
                            : ref
                                  .read(familyRepositoryProvider)
                                  .listMembers(space.id)
                                  .unwrap(),
                      ),
                  builder: (context, snap) {
                    final members = snap.data ?? const <FamilyMember>[];
                    return Wrap(
                      spacing: 8,
                      children: [
                        for (final m in members)
                          FilterChip(
                            label: Text(m.displayName),
                            selected: _recipientUserIds.contains(m.userId),
                            onSelected: (on) => setState(
                              () => on
                                  ? _recipientUserIds.add(m.userId)
                                  : _recipientUserIds.remove(m.userId),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : () => _save(draft),
                child: Text(_busy ? '…' : s.save),
              ),
            ],
          );
        },
      ),
    );
  }

  /// One file for the whole take: segments are joined next to them. A
  /// legacy single-file draft (pre spec 02, .m4a) is uploaded as is.
  Future<String> _joinTake(StoryDraft draft) async {
    final first = draft.segments.isEmpty ? '' : draft.segments.first.path;
    if (draft.segments.length == 1 && !first.endsWith('.wav')) return first;
    final joined = await SegmentJoiner.join(
      draft.segments,
      '${File(first).parent.path}/story.wav',
    );
    return joined;
  }

  Future<void> _save(StoryDraft? draft) async {
    if (_title.text.trim().isEmpty || draft == null) return;
    setState(() => _busy = true);
    try {
      final familyRepo = ref.read(familyRepositoryProvider);
      final space = await familyRepo.getMySpace().unwrap();
      if (space == null) throw StateError('no space');
      final storyId = newUuid();
      final uid = ref.read(currentUserIdProvider);
      if (uid == null) throw StateError('no session');
      // Path is namespaced by uploader: the storage insert policy rejects any
      // write outside your own prefix, so no member can occupy another's path.
      final joined = await _joinTake(draft);
      final ext = joined.endsWith('.wav') ? 'wav' : 'm4a';
      final storagePath = '${space.id}/$uid/$storyId/a.$ext';
      await ref
          .read(storyRepositoryProvider)
          .uploadAudio(joined, storagePath)
          .unwrap();
      final story = Story(
        id: storyId,
        spaceId: space.id,
        title: _title.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        topic: _topic ?? draft.topic,
        approxDateLabel: _approxDate.text.trim().isEmpty
            ? null
            : _approxDate.text.trim(),
        visibility: _visibility,
        audioPath: storagePath,
        durationSeconds: draft.durationSeconds,
        createdBy: '',
        createdAt: DateTime.now(),
        narratorIds: _narratorIds.toList(),
        peopleIds: _peopleIds.toList(),
        recipientUserIds: _recipientUserIds.toList(),
        photoIds: _photoIds.toList(),
      );
      try {
        await ref.read(storyRepositoryProvider).createStory(story).unwrap();
      } on Exception catch (_) {
        // The take is already in the bucket; remove the orphan so failed saves
        // do not accumulate invisible objects, then let the error UI handle it.
        await ref
            .read(storyRepositoryProvider)
            .deleteAudio(storagePath)
            .unwrap();
        rethrow;
      }
      await ref.read(draftStoreProvider).delete(draft.id);
      if (mounted) context.go('/stories');
    } on Exception catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.errorUnknown)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
