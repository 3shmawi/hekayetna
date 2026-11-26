import 'dart:async';

import 'package:family_stories/core/router/app_routes.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/features/prompts/data/prompt_flag.dart';
import 'package:family_stories/features/prompts/data/prompt_library_loader.dart';
import 'package:family_stories/features/prompts/domain/prompt_logic.dart';
import 'package:family_stories/features/prompts/presentation/prompts_providers.dart';
import 'package:family_stories/features/settings/presentation/settings_controller.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/data/story_repository.dart';
import 'package:family_stories/features/stories/presentation/story_providers.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The feed's question of the week (spec 07, section 4). Same question for
/// everyone in the same ISO week, for the relative who has told the most
/// stories. Renders nothing with the flag off, after a dismiss this week,
/// or when there is nobody or nothing to ask.
class WeeklyPromptCard extends ConsumerStatefulWidget {
  const WeeklyPromptCard({super.key});

  @override
  ConsumerState<WeeklyPromptCard> createState() => _WeeklyPromptCardState();
}

class _WeeklyPromptCardState extends ConsumerState<WeeklyPromptCard> {
  bool _hidden = false;
  bool _shownReported = false;

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(interviewPromptsEnabledProvider).value ?? false;
    if (!enabled || _hidden) return const SizedBox.shrink();
    final lib = ref.watch(promptLibraryProvider).value;
    final store = ref.watch(savedPromptsStoreProvider).value;
    final space = ref.watch(currentSpaceProvider).value;
    if (lib == null || store == null || space == null) {
      return const SizedBox.shrink();
    }
    final today = ref.watch(promptsClockProvider)();
    final week = weekKey(today);
    if (store.isWeekDismissed(week)) return const SizedBox.shrink();

    final persons = ref.watch(personsProvider(space.id)).value ?? const [];
    final stories =
        ref.watch(storyFeedProvider(const StoryFilter())).value ??
        const <Story>[];
    final people = orderAsking([
      for (final p in persons)
        if (p.approxDeathDate == null)
          AskablePerson(
            id: p.id,
            name: p.fullName,
            storyCount: stories
                .where((s) => s.narratorIds.contains(p.id))
                .length,
          ),
    ]);
    if (people.isEmpty) return const SizedBox.shrink();
    final who = people.first;
    final answered = ref.watch(answeredPromptsProvider(who.id)).keys.toSet();
    final prompt = weeklyPrompt([
      for (final p in lib.prompts)
        if (!answered.contains(p.id)) p,
    ], today);
    if (prompt == null) return const SizedBox.shrink();

    if (!_shownReported) {
      _shownReported = true;
      unawaited(ref.read(promptEventsProvider)('weekly_prompt_shown'));
    }
    final s = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final scheme = Theme.of(context).colorScheme;
    final text = prompt.text(lang);
    // Reference: dark card, light text, the question names who to ask.
    final on = scheme.onPrimary;
    final q = text.question;
    final q1 = lang == 'en' && q.length > 1 && q[1] == q[1].toLowerCase()
        ? q[0].toLowerCase() + q.substring(1)
        : q;
    return Container(
      key: const ValueKey('weekly-prompt'),
      padding: EdgeInsets.all(AppDimens.lg),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.promptsWeekTitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: on.withValues(alpha: 0.85),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: on),
                tooltip: s.promptsDismiss,
                onPressed: () {
                  setState(() => _hidden = true);
                  unawaited(store.dismissWeek(week));
                  unawaited(
                    ref.read(promptEventsProvider)('weekly_prompt_dismissed'),
                  );
                },
              ),
            ],
          ),
          Text(
            s.promptsWeekAsk(who.name, q1),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: on),
          ),
          SizedBox(height: AppDimens.md),
          Wrap(
            spacing: AppDimens.sm,
            runSpacing: AppDimens.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: on,
                  foregroundColor: scheme.primary,
                  minimumSize: Size(0, AppDimens.buttonHeight),
                  shape: const StadiumBorder(),
                ),
                onPressed: () {
                  ref
                      .read(settingsControllerProvider.notifier)
                      .setLastNarrator(who.id);
                  unawaited(
                    ref.read(promptEventsProvider)('weekly_prompt_recorded'),
                  );
                  context.go(
                    Uri(
                      path: AppRoutes.record,
                      queryParameters: {
                        'topic': prompt.topic,
                        'prompt': prompt.id,
                      },
                    ).toString(),
                  );
                },
                child: Text(s.promptsWeekRecord(who.name)),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: on),
                onPressed: () =>
                    unawaited(context.push(AppRoutes.promptsFrom('feed'))),
                child: Text(s.promptsMore),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
