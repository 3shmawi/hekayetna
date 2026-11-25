import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/config/app_flavor.dart';
import 'package:family_stories/core/feature_flags/feature_flags.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/family/domain/family_graph.dart';
import 'package:family_stories/features/stories/data/story_repository.dart';
import 'package:family_stories/features/stories/presentation/story_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the interactive tree replaces today's list-plus-simple-tree.
/// Dev and staging builds always have it; production asks the remote flag.
final familyTreeGraphEnabledProvider = FutureProvider<bool>(
  (ref) => AppFlavor.current.isProd
      ? FeatureFlags.isEnabled(Flags.familyTreeGraph)
      : Future.value(true),
);

// ignore: specify_nonobvious_property_types, the family type is inferred
final relationshipsProvider = FutureProvider.family<List<Relationship>, String>(
  (ref, spaceId) async =>
      (await ref.watch(familyRepositoryProvider).listRelationships(spaceId))
          .unwrap(),
);

/// The whole family as a graph: people, confirmed and pending
/// relationships, who "me" is, and each person's accessible stories.
// ignore: specify_nonobvious_property_types, the family type is inferred
final familyGraphProvider = FutureProvider.family<FamilyGraph, String>((
  ref,
  spaceId,
) async {
  final persons = await ref.watch(personsProvider(spaceId).future);
  final rels = await ref.watch(relationshipsProvider(spaceId).future);
  final members = await ref.watch(membersProvider(spaceId).future);
  final stories = await ref.watch(
    storyFeedProvider(const StoryFilter()).future,
  );
  final uid = ref.watch(currentUserIdProvider);
  String? meId;
  for (final m in members) {
    if (m.userId == uid) meId = m.personId;
  }
  final byNarrator = <String, List<int>>{};
  for (final s in stories) {
    for (final id in s.narratorIds) {
      byNarrator.putIfAbsent(id, () => []).add(s.durationSeconds);
    }
  }
  return FamilyGraph.build(
    persons: persons,
    relationships: rels,
    meId: meId,
    storiesByNarrator: byNarrator,
  );
});
