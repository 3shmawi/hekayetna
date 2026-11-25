import 'dart:async';
import 'dart:io';

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/adaptive/adaptive.dart';
import 'package:family_stories/core/ids.dart';
import 'package:family_stories/core/theme/app_colors.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/photos/data/models.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/data/story_repository.dart';
import 'package:family_stories/features/stories/domain/story_topics.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

/// Home: stories first, always. Filter chips for topic and narrator; every
/// card is already filtered server-side by what the member may access.
/// `m:ss` label for a story's recorded duration.
String _durationLabel(Story story) {
  final m = story.durationSeconds ~/ 60;
  final sec = (story.durationSeconds % 60).toString().padLeft(2, '0');
  return '$m:$sec';
}

class StoryFeedScreen extends ConsumerStatefulWidget {
  const StoryFeedScreen({super.key});

  @override
  ConsumerState<StoryFeedScreen> createState() => _StoryFeedScreenState();
}

class _StoryFeedScreenState extends ConsumerState<StoryFeedScreen> {
  // Bumped after a space is created or joined so getMySpace refetches.
  var _spaceTick = 0;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final demo = ref.watch(isDemoModeProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.stories),
        actions: [
          IconButton(
            key: const Key('home_settings_button'),
            tooltip: s.settingsTitle,
            icon: Icon(AdaptiveIcons.settings(context)),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: FutureBuilder(
        future: Future.value(
          _spaceTick,
        ).then((_) => ref.read(familyRepositoryProvider).getMySpace()),
        builder: (context, spaceSnap) {
          final space = spaceSnap.data;
          if (spaceSnap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (space == null) {
            return _NoSpace(onSpaceChanged: () => setState(() => _spaceTick++));
          }
          return Column(
            children: [
              if (demo)
                Container(
                  width: double.infinity,
                  color: AppColors.gold.withValues(alpha: 0.15),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Text(s.demoMode, style: const TextStyle(fontSize: 13)),
                ),
              Expanded(child: _StoryList(spaceId: space.id)),
            ],
          );
        },
      ),
      // No space yet: no record button. Recording needs a space, so a button
      // here would promise an action that can only fail.
      floatingActionButton: FutureBuilder(
        future: ref.read(familyRepositoryProvider).getMySpace(),
        builder: (context, snap) => snap.data == null
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                onPressed: () => context.go('/record'),
                icon: const Icon(Icons.mic),
                label: Text(s.recordAStory),
              ),
      ),
    );
  }
}

class _NoSpace extends ConsumerStatefulWidget {
  const _NoSpace({required this.onSpaceChanged});
  final VoidCallback onSpaceChanged;

  @override
  ConsumerState<_NoSpace> createState() => _NoSpaceState();
}

class _NoSpaceState extends ConsumerState<_NoSpace> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  var _busy = false;

  Future<void> _create() async {
    if (_name.text.trim().isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(familyRepositoryProvider).createSpace(_name.text.trim());
      widget.onSpaceChanged();
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

  Future<void> _join() async {
    if (_code.text.trim().isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(familyRepositoryProvider).joinSpace(_code.text.trim());
      widget.onSpaceChanged();
    } on Exception catch (e) {
      if (mounted) {
        // A removed member gets a truthful answer, not a generic failure.
        final removed = e.toString().contains('member_removed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              removed
                  ? context.l10n.errorJoinRemoved
                  : context.l10n.errorUnknown,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        const Icon(
          Icons.auto_stories_outlined,
          size: 56,
          color: AppColors.terracotta,
        ),
        const SizedBox(height: 16),
        Text(
          s.welcomeTitle,
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          s.welcomeBody,
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Text(s.startSpaceTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          decoration: InputDecoration(labelText: s.spaceName),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _create,
          child: Text(s.createSpace),
        ),
        const SizedBox(height: 32),
        Text(s.joinSpaceTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(s.joinSpaceHint, style: const TextStyle(color: AppColors.inkSoft)),
        const SizedBox(height: 12),
        TextField(
          controller: _code,
          decoration: InputDecoration(labelText: s.inviteCode),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _busy ? null : _join,
          child: Text(s.joinSpace),
        ),
      ],
    );
  }
}

class _StoryList extends ConsumerStatefulWidget {
  const _StoryList({required this.spaceId});
  final String spaceId;

  @override
  ConsumerState<_StoryList> createState() => _StoryListState();
}

class _StoryListState extends ConsumerState<_StoryList> {
  String? _topic;
  String? _narratorId;
  String? _personId;
  String? _period;

  Future<List<Person>>? _persons;

  @override
  void initState() {
    super.initState();
    _persons = ref.read(familyRepositoryProvider).listPersons(widget.spaceId);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return Column(
      children: [
        // Discovery filters. Server-side RLS already limits which stories
        // exist for this member; these only narrow within that set.
        // Wrap, not a scrolling row: every filter stays reachable on a
        // phone without horizontal scrolling past the others.
        // Flexible + scroll: during route transitions and on short screens
        // the filter block must squeeze instead of overflowing.
        Flexible(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Narrator filter FIRST: it must be reachable without
                  // scrolling
                  // past the whole topic list on a phone.
                  FutureBuilder<List<Person>>(
                    future: _persons,
                    builder: (context, snap) {
                      final persons = snap.data ?? const <Person>[];
                      if (persons.isEmpty) return const SizedBox.shrink();
                      // A Wrap, not a Row: the two dropdowns must fold onto two
                      // lines instead of overflowing a narrow phone.
                      return Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 170),
                              child: DropdownButton<String?>(
                                isExpanded: true,
                                value: _narratorId,
                                hint: Text(s.allNarrators),
                                underline: const SizedBox.shrink(),
                                items: [
                                  DropdownMenuItem(child: Text(s.allNarrators)),
                                  for (final p in persons)
                                    DropdownMenuItem(
                                      value: p.id,
                                      child: Text(p.fullName),
                                    ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _narratorId = v),
                              ),
                            ),
                          ),
                          // "Person in this story" is the mentioned-people
                          // filter;
                          // narrator above is who told it. Different semantics.
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 170),
                              child: DropdownButton<String?>(
                                isExpanded: true,
                                value: _personId,
                                hint: Text(s.allPeople),
                                underline: const SizedBox.shrink(),
                                items: [
                                  DropdownMenuItem(child: Text(s.allPeople)),
                                  for (final p in persons)
                                    DropdownMenuItem(
                                      value: p.id,
                                      child: Text(p.fullName),
                                    ),
                                ],
                                onChanged: (v) => setState(() => _personId = v),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  // Approximate-period filter. Ranges are inclusive. Stories
                  // with no approximate year are excluded while a period filter
                  // is active: their date is unknown, not inside the range.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: DropdownButton<String?>(
                      value: _period,
                      hint: Text(s.anyPeriod),
                      underline: const SizedBox.shrink(),
                      items: [
                        DropdownMenuItem(child: Text(s.anyPeriod)),
                        DropdownMenuItem(
                          value: 'pre1960',
                          child: Text(s.periodPre1960),
                        ),
                        DropdownMenuItem(
                          value: '1960-1999',
                          child: Text(s.period1960to1999),
                        ),
                        DropdownMenuItem(
                          value: '2000+',
                          child: Text(s.period2000plus),
                        ),
                      ],
                      onChanged: (v) => setState(() => _period = v),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(s.allTopics),
                      selected: _topic == null,
                      onSelected: (_) => setState(() => _topic = null),
                    ),
                  ),
                  for (final t in kStoryTopics)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(topicLabel(s, t)),
                        selected: _topic == t,
                        onSelected: (_) =>
                            setState(() => _topic = _topic == t ? null : t),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildList(context, s)),
      ],
    );
  }

  Widget _buildList(BuildContext context, AppLocalizations s) {
    return FutureBuilder<List<Story>>(
      future: ref
          .read(storyRepositoryProvider)
          .listStories(
            widget.spaceId,
            filter: StoryFilter(
              topic: _topic,
              narratorId: _narratorId,
              personId: _personId,
              yearFrom: switch (_period) {
                '1960-1999' => 1960,
                '2000+' => 2000,
                _ => null,
              },
              yearTo: switch (_period) {
                'pre1960' => 1959,
                '1960-1999' => 1999,
                _ => null,
              },
            ),
          ),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final stories = snap.data ?? const <Story>[];
        if (stories.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.graphic_eq,
                    size: 48,
                    color: AppColors.inkSoft,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s.noStoriesTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(s.noStoriesBody, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.go('/record'),
                    icon: const Icon(Icons.mic),
                    label: Text(s.recordAStory),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: stories.length,
          itemBuilder: (context, i) {
            final story = stories[i];
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  story.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  [
                    if (story.approxDateLabel != null) story.approxDateLabel!,
                    _durationLabel(story),
                    if (story.topic != null) topicLabel(s, story.topic!),
                  ].join(' · '),
                ),
                trailing: Icon(switch (story.visibility) {
                  StoryVisibility.private => Icons.lock_outline,
                  StoryVisibility.selected => Icons.person_outline,
                  StoryVisibility.family => Icons.people_alt_outlined,
                }, color: AppColors.inkSoft),
                onTap: () => context.push('/stories/${story.id}'),
              ),
            );
          },
        );
      },
    );
  }
}

class StoryDetailScreen extends ConsumerWidget {
  const StoryDetailScreen({required this.storyId, super.key});
  final String storyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.l10n;
    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<Story?>(
        future: ref.read(storyRepositoryProvider).getStory(storyId),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final story = snap.data;
          if (story == null) return Center(child: Text(s.errorUnknown));
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                story.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                [
                  if (story.approxDateLabel != null) story.approxDateLabel!,
                  if (story.topic != null) topicLabel(s, story.topic!),
                ].join(' · '),
                style: const TextStyle(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 24),
              _AudioPlayer(story: story),
              if (story.description != null) ...[
                const SizedBox(height: 24),
                Text(
                  story.description!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              // Linked photos: the link is readable with story access, but a
              // photo only renders for a member who can access the photo
              // itself. Others see the frame, never the image.
              if (story.photoIds.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(s.photos, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _StoryPhotosGrid(photoIds: story.photoIds),
              ],
              const SizedBox(height: 24),
              _VisibilityNote(visibility: story.visibility),
            ],
          );
        },
      ),
    );
  }
}

class _StoryPhotosGrid extends ConsumerWidget {
  const _StoryPhotosGrid({required this.photoIds});
  final List<String> photoIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(isDemoModeProvider);
    return FutureBuilder<List<Photo>>(
      future: ref
          .read(familyRepositoryProvider)
          .getMySpace()
          .then(
            (space) => space == null
                ? <Photo>[]
                : ref.read(photoRepositoryProvider).listPhotos(space.id),
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
      future: ref.read(photoRepositoryProvider).createImageUrl(photo.imagePath),
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

class _VisibilityNote extends StatelessWidget {
  const _VisibilityNote({required this.visibility});
  final StoryVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final (icon, text) = switch (visibility) {
      StoryVisibility.private => (Icons.lock_outline, s.visPrivateDesc),
      StoryVisibility.selected => (Icons.person_outline, s.visSelectedDesc),
      StoryVisibility.family => (Icons.people_alt_outlined, s.visFamilyDesc),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.oliveTeal),
            const SizedBox(width: 12),
            Expanded(child: Text('${s.whoCanHear} $text')),
          ],
        ),
      ),
    );
  }
}

class _AudioPlayer extends ConsumerStatefulWidget {
  const _AudioPlayer({required this.story});
  final Story story;

  @override
  ConsumerState<_AudioPlayer> createState() => _AudioPlayerState();
}

class _AudioPlayerState extends ConsumerState<_AudioPlayer> {
  final _player = AudioPlayer();
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final url = await ref
          .read(storyRepositoryProvider)
          .createAudioUrl(widget.story.audioPath);
      if (url.startsWith('demo://')) {
        setState(() => _ready = true); // demo mode: no real file to play
        return;
      }
      await _player.setUrl(url);
      setState(() => _ready = true);
    } on Exception catch (_) {
      setState(() => _error = 'error');
    }
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    if (_error != null) return Text(s.errorUnknown);
    if (!_ready) return const Center(child: CircularProgressIndicator());
    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snap) {
        final playing = snap.data?.playing ?? false;
        return Row(
          children: [
            IconButton.filled(
              iconSize: 40,
              onPressed: () => playing ? _player.pause() : _player.play(),
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StreamBuilder<Duration>(
                stream: _player.positionStream,
                builder: (context, pos) {
                  final total =
                      _player.duration ??
                      Duration(seconds: widget.story.durationSeconds);
                  final value = total.inMilliseconds == 0
                      ? 0.0
                      : ((pos.data?.inMilliseconds ?? 0) / total.inMilliseconds)
                            .clamp(0.0, 1.0);
                  return LinearProgressIndicator(value: value);
                },
              ),
            ),
          ],
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
                    .then(
                      (space) => space == null
                          ? <Person>[]
                          : ref
                                .read(familyRepositoryProvider)
                                .listPersons(space.id),
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
                    .then(
                      (space) => space == null
                          ? <Photo>[]
                          : ref
                                .read(photoRepositoryProvider)
                                .listPhotos(space.id),
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
                      .then(
                        (space) => space == null
                            ? <FamilyMember>[]
                            : ref
                                  .read(familyRepositoryProvider)
                                  .listMembers(space.id),
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

  Future<void> _save(StoryDraft? draft) async {
    if (_title.text.trim().isEmpty || draft == null) return;
    setState(() => _busy = true);
    try {
      final familyRepo = ref.read(familyRepositoryProvider);
      final space = await familyRepo.getMySpace();
      if (space == null) throw StateError('no space');
      final storyId = newUuid();
      final uid = ref.read(currentUserIdProvider);
      if (uid == null) throw StateError('no session');
      // Path is namespaced by uploader: the storage insert policy rejects any
      // write outside your own prefix, so no member can occupy another's path.
      final storagePath = '${space.id}/$uid/$storyId/a.m4a';
      await ref
          .read(storyRepositoryProvider)
          .uploadAudio(draft.filePath, storagePath);
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
        await ref.read(storyRepositoryProvider).createStory(story);
      } on Exception catch (_) {
        // The take is already in the bucket; remove the orphan so failed saves
        // do not accumulate invisible objects, then let the error UI handle it.
        await ref.read(storyRepositoryProvider).deleteAudio(storagePath);
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
