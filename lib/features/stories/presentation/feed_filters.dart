import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/data/story_repository.dart';
import 'package:family_stories/features/stories/domain/story_topics.dart';
import 'package:flutter/foundation.dart';

/// What the feed's chip rows have selected: at most one chip per kind
/// (narrator, topic, decade). No selection at all is the "All" chip.
@immutable
class FeedSelection {
  const FeedSelection({this.narratorId, this.topic, this.decade});

  final String? narratorId;
  final String? topic;

  /// First year of the decade, e.g. 1950.
  final int? decade;

  bool get isAll => narratorId == null && topic == null && decade == null;

  FeedSelection toggleNarrator(String id) => FeedSelection(
    narratorId: narratorId == id ? null : id,
    topic: topic,
    decade: decade,
  );

  FeedSelection toggleTopic(String key) => FeedSelection(
    narratorId: narratorId,
    topic: topic == key ? null : key,
    decade: decade,
  );

  FeedSelection toggleDecade(int start) => FeedSelection(
    narratorId: narratorId,
    topic: topic,
    decade: decade == start ? null : start,
  );

  StoryFilter toFilter() => StoryFilter(
    narratorId: narratorId,
    topic: topic,
    yearFrom: decade,
    yearTo: decade == null ? null : decade! + 9,
  );

  @override
  bool operator ==(Object other) =>
      other is FeedSelection &&
      other.narratorId == narratorId &&
      other.topic == topic &&
      other.decade == decade;

  @override
  int get hashCode => Object.hash(narratorId, topic, decade);
}

/// The chips a feed offers, built from the stories the member can see.
@immutable
class FeedFilterOptions {
  const FeedFilterOptions({
    required this.narrators,
    required this.topics,
    required this.decades,
  });

  /// Only narrators who have stories, most stories first.
  factory FeedFilterOptions.from(List<Story> stories, List<Person> persons) {
    final counts = <String, int>{};
    for (final s in stories) {
      for (final id in s.narratorIds.toSet()) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    final byId = {for (final p in persons) p.id: p};
    final ids = counts.keys.where(byId.containsKey).toList()
      ..sort((a, b) {
        final c = counts[b]!.compareTo(counts[a]!);
        return c != 0 ? c : byId[a]!.fullName.compareTo(byId[b]!.fullName);
      });
    final used = stories.map((s) => s.topic).whereType<String>().toSet();
    final topics = [
      for (final t in kStoryTopics)
        if (used.contains(t)) t,
    ];
    final decades = {
      for (final s in stories)
        if (s.approxYear != null) s.approxYear! ~/ 10 * 10,
    }.toList()..sort();
    return FeedFilterOptions(
      narrators: [for (final id in ids) byId[id]!],
      topics: topics,
      decades: decades,
    );
  }

  final List<Person> narrators;
  final List<String> topics;
  final List<int> decades;

  bool get isEmpty => narrators.isEmpty && topics.isEmpty && decades.isEmpty;
}
