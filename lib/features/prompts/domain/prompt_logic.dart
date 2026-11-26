import 'package:family_stories/features/prompts/domain/interview_prompt.dart';

/// ISO 8601 week of [date]: the year the week belongs to and its number.
/// The week containing the year's first Thursday is week 1, weeks start on
/// Monday. Only the calendar day counts, never the time or time zone offset.
({int year, int week}) isoWeek(DateTime date) {
  final day = DateTime.utc(date.year, date.month, date.day);
  // Move to the Thursday of this ISO week; its year is the ISO year.
  final thursday = day.add(Duration(days: DateTime.thursday - day.weekday));
  final jan1 = DateTime.utc(thursday.year);
  final week = (thursday.difference(jan1).inDays ~/ 7) + 1;
  return (year: thursday.year, week: week);
}

/// A stable 32-bit hash (FNV-1a) so "the week's question" is the same on
/// every device and every run, unlike `String.hashCode`.
int stableHash(String s) {
  var h = 0x811c9dc5;
  for (final unit in s.codeUnits) {
    h ^= unit;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

/// The question of the week: the same for everyone in the same ISO week,
/// different the next week. [candidates] must already be in a stable order
/// (the library's file order) and exclude questions already answered by the
/// chosen person. Null when there is nothing to ask.
InterviewPrompt? weeklyPrompt(
  List<InterviewPrompt> candidates,
  DateTime today,
) {
  if (candidates.isEmpty) return null;
  final w = isoWeek(today);
  final index = stableHash('${w.year}-W${w.week}') % candidates.length;
  return candidates[index];
}

/// Key under which a dismissal is stored: hides the card for its week.
String weekKey(DateTime today) {
  final w = isoWeek(today);
  return '${w.year}-W${w.week}';
}

/// A relative who can tell stories, as the prompts screen sees them.
class AskablePerson {
  const AskablePerson({
    required this.id,
    required this.name,
    required this.storyCount,
    this.birthYear,
  });

  final String id;
  final String name;
  final int storyCount;
  final int? birthYear;
}

/// "Asking" chips order: people with the most stories first, then the
/// oldest (earliest birth year; unknown last), then by name for a stable
/// result.
List<AskablePerson> orderAsking(List<AskablePerson> people) {
  final sorted = [...people]
    ..sort((a, b) {
      final byStories = b.storyCount.compareTo(a.storyCount);
      if (byStories != 0) return byStories;
      final ay = a.birthYear ?? 1 << 30;
      final by = b.birthYear ?? 1 << 30;
      final byBirth = ay.compareTo(by);
      if (byBirth != 0) return byBirth;
      return a.name.compareTo(b.name);
    });
  return sorted;
}

/// Progress for one person and topic: "3 of 12 answered".
({int answered, int total}) topicProgress(
  PromptLibrary lib,
  String topic,
  Set<String> answeredIds,
) {
  final prompts = lib.forTopic(topic);
  return (
    answered: prompts.where((p) => answeredIds.contains(p.id)).length,
    total: prompts.length,
  );
}

/// "Different question": the next unanswered prompt of the same topic after
/// [currentId], wrapping around; null when everything is answered. When
/// [currentId] is unknown it starts from the beginning of the topic.
InterviewPrompt? nextUnanswered(
  PromptLibrary lib,
  String topic,
  String? currentId,
  Set<String> answeredIds,
) {
  final all = lib.forTopic(topic);
  if (all.isEmpty) return null;
  final start = currentId == null
      ? -1
      : all.indexWhere((p) => p.id == currentId);
  for (var step = 1; step <= all.length; step++) {
    final p = all[(start + step) % all.length];
    if (!answeredIds.contains(p.id) && p.id != currentId) return p;
  }
  return null;
}

/// Surprise me: a random unanswered prompt, using the caller's picker so a
/// test can fix it. Null when everything is answered.
InterviewPrompt? surprise(
  List<InterviewPrompt> prompts,
  Set<String> answeredIds,
  int Function(int max) pick,
) {
  final open = [
    for (final p in prompts)
      if (!answeredIds.contains(p.id)) p,
  ];
  if (open.isEmpty) return null;
  return open[pick(open.length)];
}

/// Saved-for-later prompts sort first; each group keeps its own order.
List<InterviewPrompt> savedFirst(
  List<InterviewPrompt> prompts,
  Set<String> savedIds,
) => [
  ...prompts.where((p) => savedIds.contains(p.id)),
  ...prompts.where((p) => !savedIds.contains(p.id)),
];
