import 'dart:async';

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/adaptive/adaptive.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/core/router/app_routes.dart';
import 'package:family_stories/core/ui/app_message.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/features/recording/data/recorder_service.dart';
import 'package:family_stories/features/recording/presentation/continue_recording_view.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/domain/story_topics.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

/// Interrupted drafts, newest first. A take cut off by a kill, a call or a
/// full phone is `interrupted` (spec 02); finished and still-recording
/// drafts are not offered here.
Future<List<StoryDraft>> interruptedDrafts(WidgetRef ref) async =>
    onlyInterrupted(await ref.read(draftStoreProvider).list());

List<StoryDraft> onlyInterrupted(List<StoryDraft> all) =>
    all.where((d) => d.status == DraftStatus.interrupted).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

/// The "Continue a recording" screen (artboard RecordResume). Replaces the
/// old "unfinished recording" dialog.
class ContinueRecordingScreen extends ConsumerStatefulWidget {
  const ContinueRecordingScreen({
    this.asSheet = false,
    this.now = DateTime.now,
    super.key,
  });

  /// The clock behind "today / yesterday". Tests and renders inject one.
  final DateTime Function() now;

  /// Shown as the launch bottom sheet (a modal route on the root navigator)
  /// instead of a page: leaving closes the sheet, then navigates.
  final bool asSheet;

  @override
  ConsumerState<ContinueRecordingScreen> createState() =>
      _ContinueRecordingScreenState();
}

class _ContinueRecordingScreenState
    extends ConsumerState<ContinueRecordingScreen> {
  List<StoryDraft>? _drafts;
  Map<String, String> _names = const {};
  AudioPlayer? _player;
  String? _playingId;
  StreamSubscription<PlayerState>? _playerSub;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(_playerSub?.cancel());
    unawaited(_player?.dispose());
    super.dispose();
  }

  /// Closes the sheet or pops the page.
  void _leave() {
    if (widget.asSheet) {
      Navigator.of(context).pop();
    } else {
      context.pop();
    }
  }

  Future<void> _load() async {
    final drafts = await interruptedDrafts(ref);
    final names = <String, String>{};
    try {
      final repo = ref.read(familyRepositoryProvider);
      final space = await repo.getMySpace().unwrap();
      if (space != null) {
        for (final p in await repo.listPersons(space.id).unwrap()) {
          names[p.id] = p.fullName;
        }
      }
    } on Object {
      // Names are a nicety; the recording is the point.
    }
    if (!mounted) return;
    if (drafts.isEmpty) {
      _leave();
      return;
    }
    setState(() {
      _drafts = drafts;
      _names = names;
    });
  }

  ResumeItem _item(StoryDraft d) {
    final s = context.l10n;
    return ResumeItem(
      id: d.id,
      title: d.topic == null ? s.resumeUntitled : topicLabel(s, d.topic!),
      narratorName: _names[d.narratorPersonId],
      stoppedAtLabel: _when(d.updatedAt),
      segmentMs: [
        for (final seg in d.segments)
          if (seg.durationMs > 0) seg.durationMs,
      ],
    );
  }

  String _when(DateTime at) => resumeWhenLabel(
    context.l10n,
    Localizations.localeOf(context).toString(),
    at,
    widget.now(),
  );

  Future<void> _togglePlay(ResumeItem item) async {
    final player = _player ??= AudioPlayer();
    if (_playingId == item.id) {
      await player.pause();
      setState(() => _playingId = null);
      return;
    }
    final draft = _drafts!.firstWhere((d) => d.id == item.id);
    final paths = [
      for (final seg in draft.segments)
        if (seg.durationMs > 0) seg.path,
    ];
    if (paths.isEmpty) return;
    // All kept segments, in recording order, as one continuous take.
    await player.setAudioSources([for (final p in paths) AudioSource.file(p)]);
    await _playerSub?.cancel();
    _playerSub = player.playerStateStream.listen((st) {
      if (st.processingState == ProcessingState.completed && mounted) {
        setState(() => _playingId = null);
      }
    });
    setState(() => _playingId = item.id);
    unawaited(player.play());
  }

  Future<void> _stopAudio() async {
    await _player?.stop();
    _playingId = null;
  }

  Future<void> _continue(ResumeItem item) async {
    await _stopAudio();
    final recorder = ref.read(recorderServiceProvider);
    if (!await recorder.ensurePermission()) return;
    await recorder.continueDraft(item.id);
    if (!mounted) return;
    if (recorder.state.error == RecorderService.continueMissingError) {
      showAppMessage(context, context.l10n.resumeMissing);
      await _load();
      return;
    }
    // The live screen takes over; its timer carries on from the kept time.
    // From the launch sheet the user may have been on another tab.
    final router = GoRouter.of(context);
    _leave();
    router.go(AppRoutes.record);
  }

  Future<void> _save(ResumeItem item) async {
    await _stopAudio();
    final store = ref.read(draftStoreProvider);
    final draft = await store.get(item.id);
    if (draft != null) {
      await store.save(
        StoryDraft(
          id: draft.id,
          segments: draft.segments,
          status: DraftStatus.finished,
          narratorPersonId: draft.narratorPersonId,
          topic: draft.topic,
          promptId: draft.promptId,
          createdAt: draft.createdAt,
          updatedAt: DateTime.now(),
        ),
      );
    }
    if (!mounted) return;
    final router = GoRouter.of(context);
    final target = AppRoutes.recordNewStory(item.id);
    if (widget.asSheet) {
      _leave();
      unawaited(router.push(target));
    } else {
      context.pushReplacement(target);
    }
  }

  Future<void> _delete(ResumeItem item) async {
    final s = context.l10n;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text(s.resumeDeleteTitle),
        content: Text(s.resumeDeleteBody),
        actions: [
          AdaptiveDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          AdaptiveDialogAction(
            isDestructive: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await _stopAudio();
    await ref.read(draftStoreProvider).delete(item.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final drafts = _drafts;
    if (drafts == null) {
      return const AppScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return ContinueRecordingView(
      items: [for (final d in drafts) _item(d)],
      playingId: _playingId,
      onPlayToggle: (i) => unawaited(_togglePlay(i)),
      onContinue: (i) => unawaited(_continue(i)),
      onSave: (i) => unawaited(_save(i)),
      onDelete: (i) => unawaited(_delete(i)),
      onClose: () {
        unawaited(_stopAudio());
        _leave();
      },
    );
  }
}

/// "yesterday at 8:40 pm", localized: am/pm and the month follow the locale.
/// Digits stay 0-9 in every language, like every other duration and time in
/// the app (the kept time next to it is 7:45, never ٧:٤٥).
String resumeWhenLabel(
  AppLocalizations s,
  String locale,
  DateTime at,
  DateTime now,
) {
  final time = _latinDigits(DateFormat.jm(locale).format(at));
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final days = today.difference(day).inDays;
  if (days == 0) return s.resumeWhenToday(time);
  if (days == 1) return s.resumeWhenYesterday(time);
  return s.resumeWhenOn(_latinDigits(DateFormat.MMMd(locale).format(at)), time);
}

String _latinDigits(String v) => v.replaceAllMapped(
  RegExp('[\u0660-\u0669\u06F0-\u06F9]'),
  (m) => ((m[0]!.codeUnitAt(0) - 0x660) % 16).toString(),
);
