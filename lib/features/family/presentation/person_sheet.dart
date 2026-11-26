import 'dart:async';

import 'package:family_stories/core/adaptive/adaptive.dart';
import 'package:family_stories/core/analytics/analytics.dart';
import 'package:family_stories/core/router/app_routes.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/features/family/domain/family_graph.dart';
import 'package:family_stories/features/family/domain/kinship.dart';
import 'package:family_stories/features/prompts/data/prompt_flag.dart';
import 'package:family_stories/features/stories/data/story_repository.dart';
import 'package:family_stories/features/stories/domain/story_topics.dart';
import 'package:family_stories/features/stories/player/audio_player_controller.dart';
import 'package:family_stories/features/stories/presentation/story_providers.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// What the person sheet and the long-press menu can ask the page to do.
enum PersonAction { record, addRelative, edit, photos, seeAll }

/// Tap on a node: who they are, their voices, and quick actions.
/// Returns the action the user chose, if any.
Future<PersonAction?> showPersonSheet(
  BuildContext context, {
  required FamilyGraph graph,
  required String personId,
}) {
  unawaited(Analytics.capture('person_sheet_opened'));
  return showAppSheet<PersonAction>(
    context,
    handleInside: true,
    builder: (_) => PersonSheet(graph: graph, personId: personId),
  );
}

class PersonSheet extends ConsumerStatefulWidget {
  const PersonSheet({required this.graph, required this.personId, super.key});

  final FamilyGraph graph;
  final String personId;

  @override
  ConsumerState<PersonSheet> createState() => _PersonSheetState();
}

class _PersonSheetState extends ConsumerState<PersonSheet> {
  String? _topic;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final graph = widget.graph;
    final person = graph.persons[widget.personId];
    if (person == null) return const SizedBox.shrink();
    final all = ref.watch(storyFeedProvider(const StoryFilter())).value ?? [];
    final mine = [
      for (final s in all)
        if (s.narratorIds.contains(person.id)) s,
    ];
    final shown = _topic == null
        ? mine
        : [
            for (final s in mine)
              if (s.topic == _topic) s,
          ];
    final topics = <String, int>{};
    for (final s in mine) {
      final t = s.topic;
      if (t != null) topics[t] = (topics[t] ?? 0) + 1;
    }
    final me = graph.meId;
    final relation = me == null
        ? null
        : l10n.kinshipLabel(kinshipKey(graph, me, person.id));
    final years = [
      person.approxBirthDate,
      person.approxDeathDate,
    ].whereType<String>().join(' — ');
    final minutes = (mine.fold<int>(0, (a, s) => a + s.durationSeconds) / 60)
        .round();
    final player = ref.read(audioPlayerControllerProvider.notifier);

    return ListView(
      shrinkWrap: true,
      padding: EdgeInsetsDirectional.fromSTEB(
        AppDimens.lg,
        0,
        AppDimens.lg,
        AppDimens.lg,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 44,
              child: Text(
                person.fullName.characters.first,
                style: AppTextStyles.title,
              ),
            ),
            SizedBox(width: AppDimens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(person.fullName, style: AppTextStyles.title),
                  if (relation != null && me != person.id) Text(relation),
                  if (years.isNotEmpty)
                    Text(
                      years,
                      style: AppTextStyles.caption.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  if (mine.isNotEmpty)
                    Text(
                      l10n.personVoicesSummary(mine.length, minutes),
                      style: AppTextStyles.caption.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                ],
              ),
            ),
            // Artboard PersonSheet: an X at the end of the header row.
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: MaterialLocalizations.of(context).closeButtonLabel,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        SizedBox(height: AppDimens.md),
        if (mine.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppDimens.md),
            child: Text(l10n.personNoStories),
          ),
        if (mine.isEmpty &&
            (ref.watch(interviewPromptsEnabledProvider).value ?? false))
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.of(context).maybePop();
                unawaited(router.push(AppRoutes.prompts));
              },
              child: Text(l10n.promptsTitle),
            ),
          ),
        _ActionButtons(
          recordLabel: l10n.personRecordWith(person.fullName),
          playAllLabel: l10n.personPlayAll,
          playAll: mine.isEmpty
              ? null
              : AppButton.primary(
                  label: l10n.personPlayAll,
                  icon: AdaptiveIcons.play(context),
                  onPressed: () {
                    unawaited(Analytics.capture('person_play_all'));
                    unawaited(player.playQueue(mine));
                    Navigator.of(context).pop();
                  },
                ),
          record: AppButton.secondary(
            label: l10n.personRecordWith(person.fullName),
            icon: AdaptiveIcons.record(context),
            onPressed: () => Navigator.of(context).pop(PersonAction.record),
          ),
        ),
        if (topics.isNotEmpty) ...[
          SizedBox(height: AppDimens.lg),
          AppSectionLabel(l10n.personTopics),
          Wrap(
            spacing: AppDimens.sm,
            children: [
              for (final e in topics.entries)
                AppChip(
                  label: '${topicLabel(l10n, e.key)} ${e.value}',
                  selected: _topic == e.key,
                  onTap: () =>
                      setState(() => _topic = _topic == e.key ? null : e.key),
                ),
            ],
          ),
        ],
        if (shown.isNotEmpty) ...[
          SizedBox(height: AppDimens.lg),
          AppSectionLabel(l10n.personVoices),
          for (final s in shown.take(3))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                child: Icon(AdaptiveIcons.play(context), size: 20),
              ),
              title: Text(s.title),
              subtitle: s.topic == null
                  ? null
                  : Text(topicLabel(l10n, s.topic!)),
              trailing: Text(
                _mmss(s.durationSeconds),
                textDirection: TextDirection.ltr,
                style: AppTextStyles.caption.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              onTap: () => unawaited(player.playStory(s)),
            ),
          if (shown.length > 3)
            TextButton(
              onPressed: () => Navigator.of(context).pop(PersonAction.seeAll),
              child: Text(l10n.personSeeAll(shown.length)),
            ),
        ],
        SizedBox(height: AppDimens.lg),
        Wrap(
          spacing: AppDimens.sm,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(PersonAction.photos),
              child: Text(l10n.personPhotos),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(PersonAction.edit),
              child: Text(l10n.editPerson),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(PersonAction.addRelative),
              child: Text(l10n.personAddRelative),
            ),
          ],
        ),
      ],
    );
  }
}

/// Long press on a node: the same quick actions the sheet has, nothing else.
Future<PersonAction?> showPersonQuickMenu(
  BuildContext context, {
  required String name,
}) {
  final l10n = context.l10n;
  return showAppSheet<PersonAction>(
    context,
    builder: (sheet) => Padding(
      padding: EdgeInsets.only(bottom: AppDimens.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(AdaptiveIcons.record(sheet)),
            title: Text(l10n.personRecordWith(name)),
            onTap: () => Navigator.of(sheet).pop(PersonAction.record),
          ),
          ListTile(
            leading: Icon(AdaptiveIcons.invite(sheet)),
            title: Text(l10n.personAddRelative),
            onTap: () => Navigator.of(sheet).pop(PersonAction.addRelative),
          ),
          ListTile(
            leading: Icon(AdaptiveIcons.account(sheet)),
            title: Text(l10n.editPerson),
            onTap: () => Navigator.of(sheet).pop(PersonAction.edit),
          ),
        ],
      ),
    ),
  );
}

String _mmss(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
    '${(seconds % 60).toString().padLeft(2, '0')}';

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.playAll,
    required this.record,
    required this.recordLabel,
    required this.playAllLabel,
  });

  final Widget? playAll;
  final Widget record;
  final String recordLabel;
  final String playAllLabel;

  /// Width one button needs to show [label] on a single line, with its icon
  /// and padding (the same numbers AppButton uses).
  double _needed(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: AppTextStyles.label),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return painter.width +
        AppDimens.iconMd +
        AppDimens.sm +
        2 * AppDimens.xl +
        2;
  }

  @override
  Widget build(BuildContext context) {
    if (playAll == null) return record;
    return LayoutBuilder(
      builder: (context, box) {
        final half = (box.maxWidth - AppDimens.sm) / 2;
        final fits =
            _needed(context, recordLabel) <= half &&
            _needed(context, playAllLabel) <= half;
        if (fits) {
          return Row(
            children: [
              Expanded(child: playAll!),
              SizedBox(width: AppDimens.sm),
              Expanded(child: record),
            ],
          );
        }
        return Column(
          children: [
            playAll!,
            SizedBox(height: AppDimens.sm),
            record,
          ],
        );
      },
    );
  }
}
