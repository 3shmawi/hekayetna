import 'dart:convert';
import 'dart:io';

import 'package:family_stories/features/prompts/data/saved_prompts_store.dart';
import 'package:family_stories/features/prompts/domain/interview_prompt.dart';
import 'package:family_stories/features/prompts/domain/prompt_logic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

PromptLibrary _lib() => PromptLibrary.fromJson(
  jsonDecode(File('assets/prompts/prompts.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  final lib = _lib();

  group('isoWeek', () {
    test('known dates', () {
      expect(isoWeek(DateTime(2026)), (year: 2026, week: 1));
      expect(isoWeek(DateTime(2026, 11, 26)), (year: 2026, week: 48));
      // 2027-01-01 is a Friday: still week 53 of 2026.
      expect(isoWeek(DateTime(2027)), (year: 2026, week: 53));
      expect(isoWeek(DateTime(2024, 12, 30)), (year: 2025, week: 1));
    });

    test('Monday starts a new week, Sunday ends the old one', () {
      expect(isoWeek(DateTime(2026, 11, 22)).week, 47);
      expect(isoWeek(DateTime(2026, 11, 23)).week, 48);
    });

    test('time of day and offset never change the week', () {
      expect(
        isoWeek(DateTime(2026, 11, 22, 23, 59)),
        isoWeek(DateTime(2026, 11, 22)),
      );
    });
  });

  group('weeklyPrompt (AC-5)', () {
    final cands = lib.prompts;

    test('same for everyone in the same ISO week', () {
      final mon = weeklyPrompt(cands, DateTime(2026, 11, 23));
      final sun = weeklyPrompt(cands, DateTime(2026, 11, 29, 23, 59));
      expect(mon, isNotNull);
      expect(sun!.id, mon!.id);
    });

    test('changes in the following weeks', () {
      final ids = {
        for (var w = 0; w < 6; w++)
          weeklyPrompt(cands, DateTime(2026, 11, 23 + 7 * w))!.id,
      };
      expect(ids.length, greaterThan(1));
      expect(
        weeklyPrompt(cands, DateTime(2026, 11, 23))!.id,
        isNot(weeklyPrompt(cands, DateTime(2026, 11, 30))!.id),
      );
    });

    test('is deterministic across calls and null when nothing is left', () {
      expect(
        weeklyPrompt(cands, DateTime(2026, 3, 4))!.id,
        weeklyPrompt(cands, DateTime(2026, 3, 4))!.id,
      );
      expect(weeklyPrompt(const [], DateTime(2026, 3, 4)), isNull);
    });
  });

  test('stableHash is fixed (FNV-1a reference values)', () {
    expect(stableHash(''), 0x811c9dc5);
    expect(stableHash('a'), 0xe40c292c);
  });

  test('orderAsking: most stories, then oldest, unknown birth last', () {
    final order = orderAsking(const [
      AskablePerson(id: 'c', name: 'C', storyCount: 1, birthYear: 1950),
      AskablePerson(id: 'a', name: 'A', storyCount: 3, birthYear: 1960),
      AskablePerson(id: 'b', name: 'B', storyCount: 3, birthYear: 1940),
      AskablePerson(id: 'd', name: 'D', storyCount: 3),
    ]).map((p) => p.id).toList();
    expect(order, ['b', 'a', 'd', 'c']);
  });

  test('topicProgress counts answered prompts in the topic only', () {
    final ids = lib.forTopic('funny_memories').take(3).map((p) => p.id);
    final other = lib.forTopic('life_events').first.id;
    final p = topicProgress(lib, 'funny_memories', {...ids, other});
    expect(p, (answered: 3, total: 12));
  });

  group('nextUnanswered', () {
    final topic = lib.forTopic('life_events');

    test('skips answered, wraps, never returns the current one', () {
      final answered = {topic[1].id, topic[2].id};
      expect(
        nextUnanswered(lib, 'life_events', topic[0].id, answered)!.id,
        topic[3].id,
      );
      expect(
        nextUnanswered(lib, 'life_events', topic.last.id, const {})!.id,
        topic.first.id,
      );
    });

    test('null when all answered; starts at the beginning when unknown', () {
      expect(
        nextUnanswered(lib, 'life_events', null, {for (final p in topic) p.id}),
        isNull,
      );
      expect(
        nextUnanswered(lib, 'life_events', null, const {})!.id,
        topic.first.id,
      );
    });
  });

  test('surprise picks only unanswered; null when none', () {
    final ps = lib.forTopic('funny_memories');
    final answered = {for (final p in ps.skip(1)) p.id};
    expect(surprise(ps, answered, (max) => max - 1)!.id, ps.first.id);
    expect(surprise(ps, {for (final p in ps) p.id}, (max) => 0), isNull);
  });

  test('savedFirst keeps each group in order', () {
    final ps = lib.forTopic('funny_memories');
    final out = savedFirst(ps, {ps[5].id, ps[2].id}).map((p) => p.id).toList();
    expect(out.take(2), [ps[2].id, ps[5].id]);
    expect(out.length, ps.length);
  });

  group('SavedPromptsStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('save, unsave and list', () async {
      final s = SavedPromptsStore(await SharedPreferences.getInstance());
      expect(s.saved(), isEmpty);
      await s.setSaved('a', saved: true);
      await s.setSaved('b', saved: true);
      await s.setSaved('a', saved: false);
      expect(s.saved(), {'b'});
    });

    test('a dismissal hides the card for its own week only', () async {
      final s = SavedPromptsStore(await SharedPreferences.getInstance());
      final thisWeek = weekKey(DateTime(2026, 11, 24));
      expect(s.isWeekDismissed(thisWeek), isFalse);
      await s.dismissWeek(thisWeek);
      expect(s.isWeekDismissed(weekKey(DateTime(2026, 11, 28))), isTrue);
      expect(s.isWeekDismissed(weekKey(DateTime(2026, 11, 30))), isFalse);
    });
  });
}
