import 'dart:async';

import 'package:family_stories/core/adaptive/adaptive.dart';
import 'package:family_stories/core/analytics/analytics.dart';
import 'package:family_stories/core/router/app_routes.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/features/family/domain/family_graph.dart';
import 'package:family_stories/features/family/presentation/family_tree_canvas.dart';
import 'package:family_stories/features/family/presentation/family_tree_providers.dart';
import 'package:family_stories/features/family/presentation/person_sheet.dart';
import 'package:family_stories/features/settings/presentation/settings_controller.dart';
import 'package:family_stories/features/stories/presentation/story_providers.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The interactive family tree (spec 05): header with counts and search,
/// the pan/zoom canvas, and loading / empty / error states.
class FamilyTreePage extends ConsumerStatefulWidget {
  const FamilyTreePage({
    required this.spaceId,
    required this.spaceName,
    required this.onOpenPerson,
    super.key,
  });

  final String spaceId;
  final String spaceName;

  /// Opens a person (the person sheet lands in the next slice; until then
  /// this goes to the existing person page).
  final ValueChanged<String> onOpenPerson;

  @override
  ConsumerState<FamilyTreePage> createState() => _FamilyTreePageState();
}

class _FamilyTreePageState extends ConsumerState<FamilyTreePage> {
  final _controller = FamilyTreeController();
  bool _searching = false;
  String? _selected;
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(Analytics.capture('family_tree_opened'));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _openSheet(FamilyGraph graph, String id) async {
    setState(() => _selected = id);
    final action = await showPersonSheet(context, graph: graph, personId: id);
    if (!mounted) return;
    setState(() => _selected = null);
    _run(action, id);
  }

  Future<void> _openMenu(FamilyGraph graph, String id) async {
    final name = graph.persons[id]?.fullName ?? '';
    final action = await showPersonQuickMenu(context, name: name);
    if (!mounted) return;
    unawaited(
      Analytics.capture('person_long_press_action', {'action': ?action?.name}),
    );
    _run(action, id);
  }

  void _run(PersonAction? action, String id) {
    switch (action) {
      case null:
        return;
      case PersonAction.record:
        unawaited(Analytics.capture('person_record_started'));
        ref.read(settingsControllerProvider.notifier).setLastNarrator(id);
        unawaited(context.push(AppRoutes.record));
      case PersonAction.seeAll:
        ref.read(feedNarratorRequestProvider.notifier).request(id);
        context.go(AppRoutes.stories);
      case PersonAction.addRelative || PersonAction.edit || PersonAction.photos:
        // These use the existing person page flows.
        widget.onOpenPerson(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(familyGraphProvider(widget.spaceId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (_, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.errorUnknown, textAlign: TextAlign.center),
            SizedBox(height: AppDimens.md),
            AppButton.secondary(
              label: l10n.retry,
              onPressed: () => ref.invalidate(familyGraphProvider),
            ),
          ],
        ),
      ),
      data: (graph) {
        if (graph.persons.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(AppDimens.xl),
              child: Text(l10n.treeEmpty, textAlign: TextAlign.center),
            ),
          );
        }
        return Column(
          children: [
            _Header(
              name: widget.spaceName,
              graph: graph,
              searching: _searching,
              query: _query,
              onToggleSearch: () => setState(() {
                _searching = !_searching;
                if (!_searching) _query.clear();
              }),
              onPick: (id) {
                setState(() {
                  _searching = false;
                  _query.clear();
                });
                _controller.focusOn(id);
              },
            ),
            Expanded(
              child: FamilyTreeCanvas(
                graph: graph,
                controller: _controller,
                selectedId: _selected,
                onTapPerson: (id) => unawaited(_openSheet(graph, id)),
                onLongPressPerson: (id) => unawaited(_openMenu(graph, id)),
                onZoomed: (via) => unawaited(
                  Analytics.capture('family_tree_zoomed', {'via': via.name}),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.graph,
    required this.searching,
    required this.query,
    required this.onToggleSearch,
    required this.onPick,
  });

  final String name;
  final FamilyGraph graph;
  final bool searching;
  final TextEditingController query;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimens.lg,
        vertical: AppDimens.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTextStyles.title),
                    Text(
                      l10n.treeSummary(
                        graph.persons.length,
                        graph.totalStories,
                      ),
                      style: AppTextStyles.caption.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.treeSearchHint,
                onPressed: onToggleSearch,
                icon: Icon(
                  searching
                      ? AdaptiveIcons.close(context)
                      : AdaptiveIcons.search(context),
                ),
              ),
            ],
          ),
          if (searching) ...[
            TextField(
              controller: query,
              autofocus: true,
              decoration: InputDecoration(hintText: l10n.treeSearchHint),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: query,
              builder: (context, value, _) {
                final q = value.text.trim().toLowerCase();
                if (q.isEmpty) return const SizedBox.shrink();
                final hits = [
                  for (final p in graph.persons.values)
                    if (p.fullName.toLowerCase().contains(q)) p,
                ]..sort((a, b) => a.fullName.compareTo(b.fullName));
                if (hits.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(AppDimens.md),
                    child: Text(l10n.treeSearchNone),
                  );
                }
                return Column(
                  children: [
                    for (final p in hits.take(5))
                      ListTile(
                        title: Text(p.fullName),
                        onTap: () => onPick(p.id),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
