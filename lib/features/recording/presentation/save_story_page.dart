// Reformatting by the new wrapper pushed two existing lines past 80 chars.
// ignore_for_file: lines_longer_than_80_chars
import 'dart:async';
import 'dart:io';

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/adaptive/adaptive.dart';
import 'package:family_stories/core/analytics/analytics.dart';
import 'package:family_stories/core/network/app_failure.dart';
import 'package:family_stories/core/network/connectivity_provider.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/core/router/app_routes.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_fonts.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/core/ui/app_message.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/core/ui/auth_chrome.dart';
import 'package:family_stories/core/widgets/state_views.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/photos/data/models.dart';
import 'package:family_stories/features/recording/data/segment_joiner.dart';
import 'package:family_stories/features/settings/presentation/settings_controller.dart';
import 'package:family_stories/features/stories/data/models.dart' as m;
import 'package:family_stories/features/stories/data/story_saver.dart';
import 'package:family_stories/features/stories/domain/story_form_validation.dart';
import 'package:family_stories/features/stories/domain/story_topics.dart';
import 'package:family_stories/features/stories/domain/visibility_sentence.dart';
import 'package:family_stories/features/stories/presentation/story_providers.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

/// "Save the story": listen back, describe the story, choose who can listen
/// and save. The recording stays on the phone until the story exists.
class SaveStoryPage extends ConsumerStatefulWidget {
  const SaveStoryPage({required this.draftId, super.key});

  final String draftId;

  @override
  ConsumerState<SaveStoryPage> createState() => _SaveStoryPageState();
}

class _SaveStoryPageState extends ConsumerState<SaveStoryPage> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _dateLabel = TextEditingController();
  final _year = TextEditingController();
  m.StoryDraft? _draft;
  bool _missing = false;
  String? _topic;
  m.StoryVisibility _visibility =
      m.StoryVisibility.private; // always the default
  final _narrators = <String>{};
  final _people = <String>{};
  final _recipients = <String>{};
  final _photos = <String>{};
  bool _submitted = false;
  bool _busy = false;
  SavePhase? _phase;
  SavePhase? _failedPhase;
  AppFailure? _failure;

  AudioPlayer? _player;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _dateLabel, _year]) {
      c.dispose();
    }
    final p = _player;
    if (p != null) unawaited(p.dispose());
    super.dispose();
  }

  Future<void> _load() async {
    final draft = await ref.read(draftStoreProvider).get(widget.draftId);
    if (!mounted) return;
    if (draft == null) {
      setState(() => _missing = true);
      return;
    }
    final narrator =
        draft.narratorPersonId ??
        ref.read(settingsControllerProvider).lastNarratorId;
    setState(() {
      _draft = draft;
      _topic = draft.topic;
      if (narrator != null) _narrators.add(narrator);
    });
  }

  StoryFormInput get _input => StoryFormInput(
    title: _title.text,
    description: _description.text,
    dateLabel: _dateLabel.text,
    yearText: _year.text,
    visibility: _visibility,
    recipientCount: _recipients.length,
  );

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || _busy) return;
    setState(() {
      _submitted = true;
      _failure = null;
    });
    if (validateStoryForm(_input).isNotEmpty) return;
    setState(() {
      _busy = true;
      _phase = SavePhase.preparing;
    });
    await _player?.pause();
    final saver = ref.read(storySaverProvider);
    final result = await saver.save(
      draft,
      StorySaveRequest(
        title: _title.text,
        description: _description.text,
        dateLabel: _dateLabel.text,
        year: _input.year,
        topic: _topic,
        visibility: _visibility,
        narratorIds: _narrators.toList(),
        peopleIds: _people.toList(),
        recipientUserIds: _recipients.toList(),
        photoIds: _photos.toList(),
        waveform: ref.read(recorderServiceProvider).waveform,
      ),
      onPhase: (p) {
        if (mounted) setState(() => _phase = p);
      },
    );
    if (!mounted) return;
    switch (result) {
      case Success(:final value):
        unawaited(
          Analytics.capture('story_saved', {
            'visibility': _visibility.name,
            'narrators_count': _narrators.length,
            'has_photos': _photos.isNotEmpty,
            'minutes_bucket': _minutesBucket(draft.durationSeconds),
          }),
        );
        ref.invalidate(storyFeedProvider);
        showAppMessage(context, context.l10n.saveStorySaved);
        context.go(AppRoutes.storyDetail(value.id));
      case Failed(:final failure):
        unawaited(
          Analytics.capture('story_save_failed', {
            'failure_kind': failure.runtimeType.toString(),
          }),
        );
        setState(() {
          _busy = false;
          _failedPhase = _phase;
          _phase = null;
          _failure = failure;
        });
    }
  }

  static String _minutesBucket(int seconds) {
    final minutes = seconds / 60;
    if (minutes < 1) return '<1';
    if (minutes < 5) return '1-5';
    if (minutes < 15) return '5-15';
    return '15+';
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final s = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(s.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _discardTake({required bool recordAgain}) async {
    final s = context.l10n;
    final draft = _draft;
    if (draft == null) return;
    final ok = recordAgain
        ? await _confirm(
            s.saveStoryRecordAgainTitle,
            s.saveStoryRecordAgainBody,
            s.saveStoryRecordAgain,
          )
        : await _confirm(
            s.saveStoryDeleteTitle,
            s.saveStoryDeleteBody,
            s.saveStoryDelete,
          );
    if (!ok || !mounted) return;
    await _player?.stop();
    await ref.read(recorderServiceProvider).discard();
    await ref.read(draftStoreProvider).delete(draft.id);
    unawaited(Analytics.capture('recording_take_discarded'));
    if (!mounted) return;
    context.go(recordAgain ? AppRoutes.record : AppRoutes.stories);
  }

  Future<void> _togglePlay() async {
    final draft = _draft;
    if (draft == null) return;
    var player = _player;
    if (player == null) {
      player = _player = AudioPlayer();
      try {
        final first = draft.segments.isEmpty ? '' : draft.segments.first.path;
        final multi = draft.segments.length > 1 || first.endsWith('.wav');
        final path = multi
            ? await SegmentJoiner.join(
                draft.segments,
                '${File(first).parent.path}/preview.wav',
              )
            : first;
        await player.setFilePath(path);
      } on Exception catch (_) {
        _player = null;
        await player.dispose();
        if (mounted) {
          showAppMessage(context, context.l10n.saveStoryMissing);
        }
        return;
      }
    }
    if (player.playing) {
      await player.pause();
    } else {
      final dur = player.duration;
      if (dur != null && player.position >= dur) {
        await player.seek(Duration.zero);
      }
      unawaited(player.play());
    }
    if (mounted) setState(() {});
  }

  String? _errorText(StoryFormError e, AppLocalizations s) => switch (e) {
    StoryFormError.titleEmpty => s.saveStoryErrTitleEmpty,
    StoryFormError.titleTooLong => s.saveStoryErrTitleTooLong,
    StoryFormError.descriptionTooLong => s.saveStoryErrDescriptionTooLong,
    StoryFormError.dateLabelTooLong => s.saveStoryErrDateTooLong,
    StoryFormError.yearInvalid => s.saveStoryErrYear,
    StoryFormError.noRecipients => s.saveStoryErrNoRecipients,
  };

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final online = ref.watch(onlineProvider).value ?? true;
    final space = ref.watch(currentSpaceProvider).value;
    final persons = space == null
        ? const <Person>[]
        : ref.watch(personsProvider(space.id)).value ?? const <Person>[];
    final members = space == null
        ? const <FamilyMember>[]
        : ref.watch(membersProvider(space.id)).value ?? const <FamilyMember>[];
    final photos = space == null
        ? const <Photo>[]
        : ref.watch(spacePhotosProvider(space.id)).value ?? const <Photo>[];
    final errors = _submitted
        ? validateStoryForm(_input).toSet()
        : const <StoryFormError>{};
    String? err(Set<StoryFormError> which) {
      final e = errors.where(which.contains).firstOrNull;
      return e == null ? null : _errorText(e, s);
    }

    final selectedNames = [
      for (final mem in members)
        if (_recipients.contains(mem.userId)) mem.displayName,
    ];
    final hk = context.hk;

    return AuthTheme(
      child: Builder(
        builder: (context) => AppScaffold(
          background: AuthPalette.of(context).background,
          liftBottomOverKeyboard: true,
          title: s.saveStoryTitle,
          leading: AppIconButton(
            icon: AdaptiveIcons.back(context),
            tooltip: s.saveStoryBack,
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(AppRoutes.record),
          ),
          bottom: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!online)
                Padding(
                  padding: EdgeInsets.only(bottom: AppDimens.sm),
                  child: Text(
                    s.saveStoryOffline,
                    style: AppTextStyles.caption.copyWith(color: hk.inkSoft),
                  ),
                ),
              if (_busy && _phase != null)
                Padding(
                  padding: EdgeInsets.only(bottom: AppDimens.sm),
                  child: Text(switch (_phase!) {
                    SavePhase.preparing => s.saveStoryPreparing,
                    SavePhase.uploading => s.saveStoryUploading,
                    SavePhase.creating => s.saveStoryCreating,
                  }, style: AppTextStyles.caption.copyWith(color: hk.inkSoft)),
                ),
              if (_failure != null)
                Padding(
                  padding: EdgeInsets.only(bottom: AppDimens.sm),
                  child: Text(
                    _failure is TimeoutFailure
                        ? s.saveStoryStillSending
                        : '${switch (_failedPhase) {
                            SavePhase.preparing || null => s.saveStoryFailedPrepare,
                            SavePhase.uploading => s.saveStoryFailedUpload,
                            SavePhase.creating => s.saveStoryFailedCreate,
                          }} ${s.saveStoryFailed} ${_failure!.message(s)}',
                    style: AppTextStyles.caption.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              AppButton.primary(
                label: _failure != null ? s.retry : s.saveStoryButton,
                busy: _busy,
                onPressed: online && _draft != null && !_busy ? _save : null,
              ),
            ],
          ),
          body: _missing
              ? Center(child: Text(s.saveStoryMissing))
              : _draft == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    AppDimens.lg,
                    AppDimens.sm,
                    AppDimens.lg,
                    AppDimens.xl,
                  ),
                  children: [
                    _TakeCard(
                      duration: Duration(seconds: _draft!.durationSeconds),
                      playing: _player?.playing ?? false,
                      onToggle: _togglePlay,
                      onRecordAgain: () => _discardTake(recordAgain: true),
                      onDelete: () => _discardTake(recordAgain: false),
                    ),
                    SizedBox(height: AppDimens.lg),
                    AuthField(
                      label: s.storyTitle,
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      errorText: err({
                        StoryFormError.titleEmpty,
                        StoryFormError.titleTooLong,
                      }),
                      onChanged: (_) => setState(() {}),
                    ),
                    SizedBox(height: AppDimens.md),
                    AuthField(
                      label: s.description,
                      controller: _description,
                      maxLines: 3,
                      errorText: err({StoryFormError.descriptionTooLong}),
                      onChanged: (_) => setState(() {}),
                    ),
                    SizedBox(height: AppDimens.md),
                    AuthField(
                      label: s.approxDate,
                      controller: _dateLabel,
                      errorText: err({StoryFormError.dateLabelTooLong}),
                      onChanged: (_) => setState(() {}),
                    ),
                    SizedBox(height: AppDimens.md),
                    AuthField(
                      label: s.saveStoryYear,
                      controller: _year,
                      keyboardType: TextInputType.number,
                      errorText: err({StoryFormError.yearInvalid}),
                      onChanged: (_) => setState(() {}),
                    ),
                    SizedBox(height: AppDimens.lg),
                    AppSectionLabel(s.topic),
                    _ChipWrap(
                      children: [
                        AppChip(
                          label: s.noTopic,
                          selected: _topic == null,
                          onTap: () => setState(() => _topic = null),
                        ),
                        for (final t in kStoryTopics)
                          AppChip(
                            label: topicLabel(s, t),
                            selected: _topic == t,
                            onTap: () => setState(() => _topic = t),
                          ),
                      ],
                    ),
                    if (persons.isNotEmpty) ...[
                      SizedBox(height: AppDimens.lg),
                      AppSectionLabel(s.narrators),
                      _ChipWrap(
                        children: [
                          for (final p in persons)
                            AppChip(
                              label: p.fullName,
                              selected: _narrators.contains(p.id),
                              onTap: () =>
                                  setState(() => _toggle(_narrators, p.id)),
                            ),
                        ],
                      ),
                      SizedBox(height: AppDimens.lg),
                      AppSectionLabel(s.peopleMentioned),
                      _ChipWrap(
                        children: [
                          for (final p in persons)
                            AppChip(
                              label: p.fullName,
                              selected: _people.contains(p.id),
                              onTap: () =>
                                  setState(() => _toggle(_people, p.id)),
                            ),
                        ],
                      ),
                    ],
                    // Linking a photo never widens the photo's own audience; only
                    // photos the member can already see are listed.
                    if (photos.isNotEmpty) ...[
                      SizedBox(height: AppDimens.lg),
                      AppSectionLabel(s.linkPhotos),
                      _ChipWrap(
                        children: [
                          for (final p in photos)
                            AppChip(
                              label:
                                  p.caption ??
                                  p.approxDateLabel ??
                                  p.id.substring(0, 8),
                              selected: _photos.contains(p.id),
                              onTap: () =>
                                  setState(() => _toggle(_photos, p.id)),
                            ),
                        ],
                      ),
                    ],
                    SizedBox(height: AppDimens.xl),
                    AppSectionLabel(s.whoCanHear),
                    SizedBox(height: AppDimens.sm),
                    VisibilityPicker(
                      filled: VisibilityFill(
                        selected: AuthPalette.of(context).primary,
                        onSelected: AuthPalette.of(context).onPrimary,
                        idle: AuthPalette.of(context).field,
                        onIdle: AuthPalette.of(context).text,
                        serif: AppFonts.authDisplay,
                      ),
                      value: _toPicker(_visibility),
                      onChanged: (v) =>
                          setState(() => _visibility = _fromPicker(v)),
                      consequenceText: visibilitySentence(
                        s,
                        visibility: _visibility,
                        selectedNames: selectedNames,
                        familyCount: members.length,
                      ),
                    ),
                    if (_visibility == m.StoryVisibility.selected) ...[
                      SizedBox(height: AppDimens.md),
                      _ChipWrap(
                        children: [
                          for (final mem in members)
                            AppChip(
                              label: mem.displayName,
                              selected: _recipients.contains(mem.userId),
                              onTap: () => setState(
                                () => _toggle(_recipients, mem.userId),
                              ),
                            ),
                        ],
                      ),
                      if (err({StoryFormError.noRecipients}) case final text?)
                        Padding(
                          padding: EdgeInsets.only(top: AppDimens.sm),
                          child: Text(
                            text,
                            style: AppTextStyles.caption.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  static void _toggle(Set<String> set, String id) =>
      set.contains(id) ? set.remove(id) : set.add(id);

  static StoryVisibility _toPicker(m.StoryVisibility v) => switch (v) {
    m.StoryVisibility.private => StoryVisibility.onlyMe,
    m.StoryVisibility.selected => StoryVisibility.selectedPeople,
    m.StoryVisibility.family => StoryVisibility.wholeFamily,
  };

  static m.StoryVisibility _fromPicker(StoryVisibility v) => switch (v) {
    StoryVisibility.onlyMe => m.StoryVisibility.private,
    StoryVisibility.selectedPeople => m.StoryVisibility.selected,
    StoryVisibility.wholeFamily => m.StoryVisibility.family,
  };
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: AppDimens.sm),
    child: Wrap(
      spacing: AppDimens.sm,
      runSpacing: AppDimens.sm,
      children: children,
    ),
  );
}

class _TakeCard extends StatelessWidget {
  const _TakeCard({
    required this.duration,
    required this.playing,
    required this.onToggle,
    required this.onRecordAgain,
    required this.onDelete,
  });

  final Duration duration;
  final bool playing;
  final VoidCallback onToggle;
  final VoidCallback onRecordAgain;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final mm = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final p = AuthPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.fieldRaised,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(AppDimens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton.filled(
                  icon: Icon(
                    playing
                        ? AdaptiveIcons.pause(context)
                        : AdaptiveIcons.play(context),
                  ),
                  tooltip: playing ? s.saveStoryPauseListen : s.saveStoryPlay,
                  onPressed: onToggle,
                  style: IconButton.styleFrom(
                    backgroundColor: p.primary,
                    foregroundColor: p.onPrimary,
                    minimumSize: Size.square(AppDimens.targetMin),
                  ),
                ),
                SizedBox(width: AppDimens.sm),
                Text(
                  '$mm:$ss',
                  style: AppTextStyles.title,
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
            SizedBox(height: AppDimens.sm),
            Row(
              children: [
                Expanded(
                  child: AppButton.secondary(
                    wrap: true,
                    label: s.saveStoryRecordAgain,
                    onPressed: onRecordAgain,
                  ),
                ),
                SizedBox(width: AppDimens.md),
                Expanded(
                  child: AppButton.destructive(
                    wrap: true,
                    label: s.saveStoryDelete,
                    onPressed: onDelete,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
