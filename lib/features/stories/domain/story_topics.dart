import 'package:family_stories/l10n/l10n.dart';

/// Stable topic keys stored on stories. Labels live in the ARB files as
/// `topic_<key>`; use [topicLabel] to render one.
const kStoryTopics = <String>[
  'childhood_first_home',
  'parents_grandparents',
  'how_parents_met',
  'weddings_beginnings',
  'ramadan_eid_traditions',
  'life_events',
  'funny_memories',
  'lessons_for_future',
];

String topicLabel(AppLocalizations l10n, String topic) => switch (topic) {
  'childhood_first_home' => l10n.topic_childhood_first_home,
  'parents_grandparents' => l10n.topic_parents_grandparents,
  'how_parents_met' => l10n.topic_how_parents_met,
  'weddings_beginnings' => l10n.topic_weddings_beginnings,
  'ramadan_eid_traditions' => l10n.topic_ramadan_eid_traditions,
  'life_events' => l10n.topic_life_events,
  'funny_memories' => l10n.topic_funny_memories,
  'lessons_for_future' => l10n.topic_lessons_for_future,
  // Forward-compatible: a topic from a newer app version still renders.
  _ => topic,
};
