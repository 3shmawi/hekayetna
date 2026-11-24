import 'dart:async';

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/theme/app_colors.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/recording/data/recorder_service.dart';
import 'package:family_stories/features/stories/domain/story_topics.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The heart of the product: one huge button, a timer, pause/resume, and an
/// explicit narrator choice (the person recording is not necessarily the
/// narrator). Every take is written to disk immediately and indexed as a
/// private draft; leaving the screen never loses the recording.
class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  String? _narratorId;
  String? _topic;
  String? _currentDraftId;
  bool _checkedDrafts = false;

  @override
  void initState() {
    super.initState();
    // A saved draft means an earlier session was interrupted; offer to reopen
    // it instead of silently starting over. Drafts never upload by themselves.
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerDraftResume());
  }

  Future<void> _offerDraftResume() async {
    if (_checkedDrafts) return;
    _checkedDrafts = true;
    final drafts = await ref.read(draftStoreProvider).list();
    if (drafts.isEmpty || !mounted) return;
    final s = context.l10n;
    final draft = drafts.first; // newest first
    final resume = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.draftFoundTitle),
        content: Text(s.draftFoundBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.discardDraft),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.continueDraft),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (resume ?? false) {
      unawaited(context.push('/record/preview/${draft.id}'));
    } else if (resume == false) {
      await ref.read(draftStoreProvider).delete(draft.id);
    }
  }

  Future<void> _toggle() async {
    final recorder = ref.read(recorderServiceProvider);
    final state = recorder.state;
    if (state.status == RecorderStatus.idle ||
        state.status == RecorderStatus.failed) {
      final ok = await recorder.ensurePermission();
      if (!ok) return; // permission denial shown by OS; no fake success
      final id = 'draft-${DateTime.now().millisecondsSinceEpoch}';
      // The service reserves the segment path, writes the draft to the index
      // and only then starts capture (spec 02, AC-1).
      await recorder.start(
        draftId: id,
        narratorPersonId: _narratorId,
        topic: _topic,
      );
      _currentDraftId = id;
    } else if (state.canPause) {
      await recorder.pause();
    } else if (state.canResume) {
      await recorder.resume();
    }
  }

  Future<void> _finish() async {
    final recorder = ref.read(recorderServiceProvider);
    // Closes the open segment and marks the draft finished in the index.
    await recorder.stop();
    final id = _currentDraftId;
    if (id == null) return;
    if (mounted) unawaited(context.push('/record/preview/$id'));
  }

  Future<void> _discard() async {
    final recorder = ref.read(recorderServiceProvider);
    await recorder.discard();
    final id = _currentDraftId;
    if (id != null) {
      await ref.read(draftStoreProvider).delete(id);
      _currentDraftId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final recorder = ref.watch(recorderServiceProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.recordAStory)),
      body: StreamBuilder<RecorderState>(
        stream: recorder.watch(),
        initialData: recorder.state,
        builder: (context, snap) {
          final state = snap.data!;
          final active = state.status == RecorderStatus.recording;
          final paused = state.status == RecorderStatus.paused;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NarratorPicker(
                  selected: _narratorId,
                  onChanged: (v) => setState(() => _narratorId = v),
                ),
                const SizedBox(height: 12),
                _TopicChips(
                  selected: _topic,
                  onChanged: (v) => setState(() => _topic = v),
                ),
                const Spacer(),
                Text(
                  _fmt(state.elapsed),
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.displayMedium?.copyWith(fontFeatures: const []),
                ),
                const SizedBox(height: 8),
                Text(
                  active
                      ? s.recording
                      : paused
                      ? s.paused
                      : s.tapToStart,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: AppColors.inkSoft),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Semantics(
                    button: true,
                    label: active
                        ? s.pause
                        : paused
                        ? s.resume
                        : s.tapToStart,
                    child: Material(
                      color: active ? AppColors.error : AppColors.terracotta,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _toggle,
                        child: SizedBox(
                          width: 120,
                          height: 120,
                          child: Icon(
                            active ? Icons.pause : Icons.mic,
                            size: 56,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (state.canStop)
                  FilledButton.tonal(onPressed: _finish, child: Text(s.done)),
                if (state.hasTake || state.canStop)
                  TextButton(onPressed: _discard, child: Text(s.discardDraft)),
                const Spacer(),
              ],
            ),
          );
        },
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$sec' : '$m:$sec';
  }
}

class _NarratorPicker extends ConsumerWidget {
  const _NarratorPicker({required this.selected, required this.onChanged});
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.l10n;
    return FutureBuilder<List<Person>>(
      future: ref
          .read(familyRepositoryProvider)
          .getMySpace()
          .then(
            (space) => space == null
                ? const <Person>[]
                : ref.read(familyRepositoryProvider).listPersons(space.id),
          ),
      builder: (context, snap) {
        final persons = snap.data ?? const [];
        return DropdownButtonFormField<String>(
          initialValue: selected,
          // Keeps the dropdown's inner row within a tight parent.
          isExpanded: true,
          decoration: InputDecoration(
            labelText: s.chooseNarrator,
            prefixIcon: const Icon(Icons.record_voice_over),
          ),
          items: [
            for (final p in persons)
              DropdownMenuItem(value: p.id, child: Text(p.fullName)),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}

class _TopicChips extends StatelessWidget {
  const _TopicChips({required this.selected, required this.onChanged});
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ChoiceChip(
              label: Text(s.noTopic),
              selected: selected == null,
              onSelected: (_) => onChanged(null),
            ),
          ),
          for (final t in kStoryTopics)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(topicLabel(s, t)),
                selected: selected == t,
                onSelected: (_) => onChanged(t),
              ),
            ),
        ],
      ),
    );
  }
}
