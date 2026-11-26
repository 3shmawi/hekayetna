import 'dart:async';
import 'dart:math';

import 'package:family_stories/core/router/app_routes.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/prompts/data/prompt_flag.dart';
import 'package:family_stories/features/prompts/data/prompt_library_loader.dart';
import 'package:family_stories/features/prompts/domain/interview_prompt.dart';
import 'package:family_stories/features/prompts/domain/prompt_logic.dart';
import 'package:family_stories/features/prompts/presentation/prompts_providers.dart';
import 'package:family_stories/features/settings/presentation/settings_controller.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/data/story_repository.dart';
import 'package:family_stories/features/stories/domain/story_topics.dart';
import 'package:family_stories/features/stories/presentation/story_providers.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// "Questions to ask" (spec 07). Behind the `interview_prompts` flag: with
/// the flag off the screen is empty and sends the user back to the feed.
class PromptsPage extends ConsumerStatefulWidget {
  const PromptsPage({this.pick, this.from, super.key});

  /// Where the user came from: `feed`, `record` or `person`.
  final String? from;

  /// Picks which open question "Surprise me" lands on. Tests fix it.
  final int Function(int max)? pick;

  @override
  ConsumerState<PromptsPage> createState() => _PromptsPageState();
}

class _PromptsPageState extends ConsumerState<PromptsPage> {
  String? _personId;
  String _topic = kStoryTopics.first;
  String? _highlightId;
  final _keys = <String, GlobalKey>{};
  final _random = Random();
  bool _openedReported = false;

  int _birthYear(Person p) {
    final m = RegExp(r'\d{4}').firstMatch(p.approxBirthDate ?? '');
    return m == null ? 0 : int.parse(m.group(0)!);
  }

  List<AskablePerson> _askable(List<Person> persons, List<Story> stories) {
    return orderAsking([
      for (final p in persons)
        if (p.approxDeathDate == null)
          AskablePerson(
            id: p.id,
            name: p.fullName,
            storyCount: stories
                .where((s) => s.narratorIds.contains(p.id))
                .length,
            birthYear: _birthYear(p) == 0 ? null : _birthYear(p),
          ),
    ]);
  }

  void _surprise(List<InterviewPrompt> prompts, Set<String> answered) {
    final p = surprise(prompts, answered, widget.pick ?? _random.nextInt);
    if (p == null) return;
    setState(() => _highlightId = p.id);
    unawaited(ref.read(promptEventsProvider)('prompt_surprise_me'));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[p.id]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 250),
          alignment: 0.1,
        );
      }
    });
  }

  void _ask(InterviewPrompt p, AskablePerson? who) {
    if (who != null) {
      ref.read(settingsControllerProvider.notifier).setLastNarrator(who.id);
    }
    unawaited(
      ref.read(promptEventsProvider)('prompt_asked', {'topic': p.topic}),
    );
    context.go(
      Uri(
        path: AppRoutes.record,
        queryParameters: {'topic': p.topic, 'prompt': p.id},
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final enabled = ref.watch(interviewPromptsEnabledProvider).value ?? false;
    if (!enabled) {
      return AppScaffold(title: s.promptsTitle, body: const SizedBox.shrink());
    }
    if (!_openedReported) {
      _openedReported = true;
      unawaited(
        ref.read(promptEventsProvider)('prompts_opened', {
          'from': widget.from ?? 'unknown',
        }),
      );
    }
    final lib = ref.watch(promptLibraryProvider).value;
    final space = ref.watch(currentSpaceProvider).value;
    final persons = space == null
        ? const <Person>[]
        : ref.watch(personsProvider(space.id)).value ?? const <Person>[];
    final stories =
        ref.watch(storyFeedProvider(const StoryFilter())).value ??
        const <Story>[];
    final saved = ref.watch(savedPromptsProvider).value ?? const <String>{};
    final askable = _askable(persons, stories);
    final selected = askable.where((a) => a.id == _personId).firstOrNull;
    final answeredMap = ref.watch(answeredPromptsProvider(_personId));
    final answered = answeredMap.keys.toSet();
    final lang = Localizations.localeOf(context).languageCode;
    final scheme = Theme.of(context).colorScheme;

    final prompts = lib == null
        ? const <InterviewPrompt>[]
        : savedFirst(lib.forTopic(_topic), saved);
    final progress = lib == null
        ? (answered: 0, total: 0)
        : topicProgress(lib, _topic, answered);

    return AppScaffold(
      title: s.promptsTitle,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppDimens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (askable.isNotEmpty) ...[
              AppSectionLabel(s.promptsAsking),
              SizedBox(height: AppDimens.sm),
              _ChipRow(
                children: [
                  for (final a in askable)
                    AppChip(
                      label: a.name,
                      selected: a.id == _personId,
                      onTap: () => setState(
                        () => _personId = a.id == _personId ? null : a.id,
                      ),
                    ),
                ],
              ),
              SizedBox(height: AppDimens.lg),
            ],
            _ChipRow(
              children: [
                for (final t in kStoryTopics)
                  AppChip(
                    label: topicLabel(s, t),
                    selected: t == _topic,
                    onTap: () => setState(() {
                      _topic = t;
                      _highlightId = null;
                    }),
                  ),
              ],
            ),
            SizedBox(height: AppDimens.lg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.promptsProgress(progress.answered, progress.total),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                AppButton.secondary(
                  label: s.promptsSurprise,
                  expand: false,
                  icon: Icons.casino_outlined,
                  onPressed: () => _surprise(prompts, answered),
                ),
              ],
            ),
            SizedBox(height: AppDimens.sm),
            LinearProgressIndicator(
              value: progress.total == 0
                  ? 0
                  : progress.answered / progress.total,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            SizedBox(height: AppDimens.lg),
            if (lib != null && prompts.isEmpty) Text(s.promptsEmpty),
            for (final p in prompts)
              Padding(
                key: _keys.putIfAbsent(p.id, GlobalKey.new),
                padding: EdgeInsets.only(bottom: AppDimens.md),
                child: _PromptCard(
                  prompt: p,
                  text: p.text(lang),
                  highlighted: p.id == _highlightId,
                  savedForLater: saved.contains(p.id),
                  answeredTitle: answeredMap[p.id],
                  askLabel: selected == null
                      ? s.promptsAskSomeone
                      : s.promptsAsk(selected.name),
                  tint: scheme.primaryContainer,
                  onAsk: () => _ask(p, selected),
                  onSave: () {
                    unawaited(
                      ref.read(savedPromptsProvider.notifier).toggle(p.id),
                    );
                    if (!saved.contains(p.id)) {
                      unawaited(
                        ref.read(promptEventsProvider)(
                          'prompt_saved_for_later',
                        ),
                      );
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final c in children)
          Padding(
            padding: EdgeInsetsDirectional.only(end: AppDimens.sm),
            child: c,
          ),
      ],
    ),
  );
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.prompt,
    required this.text,
    required this.highlighted,
    required this.savedForLater,
    required this.answeredTitle,
    required this.askLabel,
    required this.tint,
    required this.onAsk,
    required this.onSave,
  });

  final InterviewPrompt prompt;
  final PromptText text;
  final bool highlighted;
  final bool savedForLater;
  final String? answeredTitle;
  final String askLabel;
  final Color tint;
  final VoidCallback onAsk;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final answered = answeredTitle != null;
    return Container(
      key: ValueKey('prompt-${prompt.id}'),
      padding: EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: answered ? tint : scheme.surface,
        border: Border.all(
          color: highlighted ? scheme.primary : scheme.outlineVariant,
          width: highlighted ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text.question, style: Theme.of(context).textTheme.titleMedium),
          if (text.followUps.isNotEmpty) ...[
            SizedBox(height: AppDimens.sm),
            Text(
              text.followUps.join(' · '),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          SizedBox(height: AppDimens.md),
          if (answered)
            Text(answeredTitle!, style: Theme.of(context).textTheme.bodyMedium)
          else
            Row(
              children: [
                Expanded(
                  child: AppButton.record(
                    wrap: true,
                    label: askLabel,
                    onPressed: onAsk,
                  ),
                ),
                SizedBox(width: AppDimens.sm),
                AppIconButton(
                  icon: savedForLater ? Icons.bookmark : Icons.bookmark_border,
                  tooltip: savedForLater
                      ? s.promptsSaved
                      : s.promptsSaveForLater,
                  onPressed: onSave,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
