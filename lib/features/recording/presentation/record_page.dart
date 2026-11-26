import 'dart:async';

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/adaptive/adaptive.dart';
import 'package:family_stories/core/analytics/analytics.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/core/router/app_routes.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/ui/app_message.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/core/widgets/state_views.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/prompts/data/prompt_flag.dart';
import 'package:family_stories/features/prompts/data/prompt_library_loader.dart';
import 'package:family_stories/features/recording/data/recorder_service.dart';
import 'package:family_stories/features/recording/presentation/continue_recording_screen.dart';
import 'package:family_stories/features/recording/presentation/record_view.dart';
import 'package:family_stories/features/settings/presentation/settings_controller.dart';
import 'package:family_stories/features/stories/domain/story_topics.dart';
import 'package:family_stories/features/stories/presentation/story_providers.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Recording screen behavior: wires the recorder, the family's people and
/// the settings into [RecordView]. Every take is on disk and indexed as a
/// private draft from the first second; leaving never loses it.
class RecordPage extends ConsumerStatefulWidget {
  const RecordPage({this.topic, this.promptId, super.key});

  /// Set when opened from "Questions to ask" (spec 07): the topic and the
  /// question to show. Ignored unless the prompts flag is on.
  final String? topic;
  final String? promptId;

  @override
  ConsumerState<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends ConsumerState<RecordPage> {
  String? _topic;
  String? _currentDraftId;
  bool _checkedDrafts = false;
  int _promptIndex = 0;
  final List<double> _levels = [];
  StreamSubscription<double>? _levelSub;

  @override
  void initState() {
    super.initState();
    if (widget.topic != null && kStoryTopics.contains(widget.topic)) {
      _topic = widget.topic;
    }
    _levelSub = ref.read(recorderServiceProvider).levels.listen((v) {
      if (!mounted) return;
      setState(() {
        _levels.add(v);
        if (_levels.length > kLevelBars) _levels.removeAt(0);
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerDraftResume());
  }

  @override
  void dispose() {
    unawaited(_levelSub?.cancel());
    super.dispose();
  }

  Future<void> _offerDraftResume() async {
    if (_checkedDrafts) return;
    _checkedDrafts = true;
    // Never while a take is live (a continued draft lands here recording).
    final status = ref.read(recorderServiceProvider).state.status;
    if (status != RecorderStatus.idle) return;
    final drafts = await interruptedDrafts(ref);
    if (drafts.isEmpty || !mounted) return;
    unawaited(context.push('/record/continue'));
  }

  Future<void> _toggle() async {
    final recorder = ref.read(recorderServiceProvider);
    final state = recorder.state;
    if (state.status == RecorderStatus.idle ||
        state.status == RecorderStatus.failed) {
      final ok = await recorder.ensurePermission();
      if (!ok) return; // the OS shows the denial; no fake success
      final id = 'draft-${DateTime.now().millisecondsSinceEpoch}';
      _currentDraftId = id;
      setState(_levels.clear);
      await recorder.start(
        draftId: id,
        narratorPersonId: ref.read(settingsControllerProvider).lastNarratorId,
        topic: _topic,
      );
    } else if (state.canPause) {
      await recorder.pause();
    } else if (state.canResume) {
      await recorder.resume();
    }
  }

  Future<void> _done() async {
    final recorder = ref.read(recorderServiceProvider);
    await recorder.stop();
    final id = _currentDraftId ?? recorder.state.draftId;
    if (id != null && mounted) {
      unawaited(context.push(AppRoutes.recordNewStory(id)));
    }
  }

  Future<void> _close() async {
    final recorder = ref.read(recorderServiceProvider);
    // The draft is kept; a running take is paused, never lost.
    if (recorder.state.canPause) await recorder.pause();
    if (mounted) context.go(AppRoutes.stories);
  }

  Future<void> _pickNarrator(List<Person> persons, String spaceId) async {
    final s = context.l10n;
    final picked = await showAppSheet<String>(
      context,
      builder: (sheet) => _NarratorSheet(
        persons: persons,
        selectedId: ref.read(settingsControllerProvider).lastNarratorId,
        title: s.recordPickNarrator,
      ),
    );
    if (picked == null || !mounted) return;
    var id = picked;
    if (picked == _addPersonResult) {
      final created = await _addPerson(spaceId);
      if (created == null) return;
      id = created.id;
    }
    ref.read(settingsControllerProvider.notifier).setLastNarrator(id);
    unawaited(Analytics.capture('recording_narrator_changed'));
  }

  Future<Person?> _addPerson(String spaceId) async {
    final s = context.l10n;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.recordAddPerson),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 120,
          decoration: InputDecoration(labelText: s.recordPersonName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.done),
          ),
        ],
      ),
    );
    final name = controller.text.trim();
    controller.dispose();
    if (ok != true || name.isEmpty || !mounted) return null;
    final result = await ref
        .read(familyRepositoryProvider)
        .createPerson(
          Person(id: '', spaceId: spaceId, fullName: name, createdBy: ''),
        );
    if (!mounted) return null;
    switch (result) {
      case Success(:final value):
        ref.invalidate(personsProvider(spaceId));
        return value;
      case Failed(:final failure):
        showAppMessage(context, failure.message(context.l10n));
        return null;
    }
  }

  Future<void> _pickTopic() async {
    final s = context.l10n;
    final picked = await showAppSheet<String>(
      context,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.all(AppDimens.lg),
          children: [
            _SheetRow(
              label: s.noTopic,
              selected: _topic == null,
              onTap: () => Navigator.pop(sheet, ''),
            ),
            for (final t in kStoryTopics)
              _SheetRow(
                label: topicLabel(s, t),
                selected: _topic == t,
                onTap: () => Navigator.pop(sheet, t),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _topic = picked.isEmpty ? null : picked);
  }

  String? _note(AppLocalizations s, RecorderState state) =>
      switch (state.pauseReason) {
        PauseReason.interruption => s.recordPausedInterrupted,
        PauseReason.storage => s.recordPausedStorage,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final recorder = ref.watch(recorderServiceProvider);
    final settings = ref.watch(settingsControllerProvider);
    final space = ref.watch(currentSpaceProvider).value;
    final persons = space == null
        ? const <Person>[]
        : ref.watch(personsProvider(space.id)).value ?? const <Person>[];
    final narrator = persons
        .where((p) => p.id == settings.lastNarratorId)
        .firstOrNull;
    final prompts = starterQuestions(s);
    final flagOn = ref.watch(interviewPromptsEnabledProvider).value ?? false;
    final library = flagOn ? ref.watch(promptLibraryProvider).value : null;
    final chosen = widget.promptId == null
        ? null
        : library?.byId(widget.promptId!);
    final lang = Localizations.localeOf(context).languageCode;
    return StreamBuilder<RecorderState>(
      stream: recorder.watch(),
      initialData: recorder.state,
      builder: (context, snap) {
        final state = snap.data!;
        return RecordView(
          buttonState: switch (state.status) {
            RecorderStatus.recording => RecordButtonState.recording,
            RecorderStatus.paused => RecordButtonState.paused,
            _ => RecordButtonState.idle,
          },
          elapsed: state.elapsed,
          levels: List.of(_levels),
          narratorName: narrator?.fullName,
          draftSaved: state.draftId != null,
          canFinish: state.canStop || state.hasTake,
          topicLabel: _topic == null ? null : topicLabel(s, _topic!),
          promptText: settings.showPrompts
              ? (chosen?.text(lang).question ??
                    prompts[_promptIndex % prompts.length])
              : null,
          onDifferentQuestion: () => setState(() => _promptIndex++),
          onMoreQuestions: flagOn
              ? () => unawaited(context.push(AppRoutes.prompts))
              : null,
          note: _note(s, state),
          onClose: _close,
          onToggle: _toggle,
          onPickNarrator: () => space == null
              ? null
              : unawaited(_pickNarrator(persons, space.id)),
          onPickTopic: () => unawaited(_pickTopic()),
          onDone: _done,
        );
      },
    );
  }
}

/// The starter questions, in the current language. Authored copy: it
/// comes from the ARB files, never from a hard-coded string.
List<String> starterQuestions(AppLocalizations s) => [
  s.recordPrompt1,
  s.recordPrompt2,
  s.recordPrompt3,
  s.recordPrompt4,
];

const _addPersonResult = '__add_person__';

class _NarratorSheet extends StatelessWidget {
  const _NarratorSheet({
    required this.persons,
    required this.selectedId,
    required this.title,
  });

  final List<Person> persons;
  final String? selectedId;
  final String title;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.all(AppDimens.lg),
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: AppDimens.sm),
          for (final p in persons)
            _SheetRow(
              label: p.fullName,
              selected: p.id == selectedId,
              onTap: () => Navigator.pop(context, p.id),
            ),
          _SheetRow(
            label: s.recordAddPerson,
            selected: false,
            onTap: () => Navigator.pop(context, _addPersonResult),
          ),
        ],
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: AppDimens.targetMin,
    title: Text(label),
    trailing: selected ? Icon(AdaptiveIcons.check(context)) : null,
    selected: selected,
    onTap: onTap,
  );
}
