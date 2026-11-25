import 'package:family_stories/core/network/app_failure.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/presentation/feed_filters.dart';
import 'package:family_stories/features/stories/presentation/story_feed_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

Person _p(String id, String name) =>
    Person(id: id, spaceId: 's', fullName: name, createdBy: 'u');

Story _s(
  String id, {
  List<String> narrators = const [],
  String? topic,
  int? year,
}) => Story(
  id: id,
  spaceId: 's',
  title: 'Story $id',
  visibility: StoryVisibility.family,
  audioPath: 'a/$id',
  durationSeconds: 154,
  createdBy: 'u',
  createdAt: DateTime(2026),
  narratorIds: narrators,
  topic: topic,
  approxYear: year,
);

final List<Person> _persons = [
  _p('sitto', 'Sitto'),
  _p('giddu', 'Giddu'),
  _p('x', 'Nobody'),
];
final List<Story> _stories = [
  _s('1', narrators: ['giddu'], topic: 'funny_memories', year: 1963),
  _s('2', narrators: ['sitto'], topic: 'ramadan_eid_traditions', year: 1958),
  _s('3', narrators: ['sitto'], year: 1955),
];

Widget _view(
  AsyncValue<List<Story>> value, {
  FeedSelection selection = const FeedSelection(),
  ValueChanged<FeedSelection>? onChanged,
  VoidCallback? onRetry,
  VoidCallback? onRecord,
  VoidCallback? onAccount,
}) => StoryFeedView(
  stories: value,
  options: FeedFilterOptions.from(_stories, _persons),
  selection: selection,
  narratorNames: {for (final p in _persons) p.id: p.fullName},
  onSelectionChanged: onChanged ?? (_) {},
  onRefresh: () async {},
  onOpen: (_) {},
  onPlay: (_) {},
  onRecord: onRecord ?? () {},
  onRetry: onRetry,
  onAccount: onAccount,
);

void main() {
  group('FeedFilterOptions', () {
    final o = FeedFilterOptions.from(_stories, _persons);
    test('narrators with stories only, most stories first', () {
      expect(o.narrators.map((p) => p.id), ['sitto', 'giddu']);
    });
    test('topics that have stories, in the app order', () {
      expect(o.topics, ['ramadan_eid_traditions', 'funny_memories']);
    });
    test('decades that have stories', () {
      expect(o.decades, [1950, 1960]);
    });
  });

  group('FeedSelection', () {
    test('one chip per kind; selecting the same one clears it', () {
      var s = const FeedSelection().toggleNarrator('sitto');
      s = s.toggleNarrator('giddu');
      expect(s.narratorId, 'giddu');
      s = s.toggleTopic('funny_memories').toggleDecade(1960);
      expect(s.toFilter().yearFrom, 1960);
      expect(s.toFilter().yearTo, 1969);
      expect(s.toggleNarrator('giddu').narratorId, isNull);
      expect(s.isAll, isFalse);
      expect(const FeedSelection().isAll, isTrue);
    });
  });

  group('StoryFeedView', () {
    testWidgets('lists cards with the "Recently added" label', (t) async {
      await t.pumpApp(_view(AsyncData(_stories)));
      expect(find.text('Story 1'), findsOneWidget);
      expect(find.text('RECENTLY ADDED'), findsOneWidget);
      expect(find.textContaining('Sitto'), findsWidgets);
    });

    testWidgets('the settings button keeps its key (integration tests)', (
      t,
    ) async {
      var opened = 0;
      await t.pumpApp(_view(AsyncData(_stories), onAccount: () => opened++));
      await t.tap(find.byKey(const Key('home_settings_button')));
      expect(opened, 1);
    });

    testWidgets('chips report narrator, topic, decade and All', (t) async {
      final picks = <FeedSelection>[];
      await t.pumpApp(_view(AsyncData(_stories), onChanged: picks.add));
      final row = find.byType(Scrollable).first;
      Finder chip(String label) => find.descendant(
        of: find.byType(ListView).first,
        matching: find.text(label),
      );
      await t.tap(chip('Sitto'));
      await t.scrollUntilVisible(
        chip(l10nEn.topic_funny_memories),
        100,
        scrollable: row,
      );
      await t.ensureVisible(chip(l10nEn.topic_funny_memories));
      await t.pumpAndSettle();
      await t.tap(chip(l10nEn.topic_funny_memories));
      await t.scrollUntilVisible(chip('1950s'), 100, scrollable: row);
      await t.ensureVisible(chip('1950s'));
      await t.pumpAndSettle();
      await t.tap(chip('1950s'));
      await t.scrollUntilVisible(chip('All'), -100, scrollable: row);
      await t.ensureVisible(chip('All'));
      await t.pumpAndSettle();
      await t.tap(chip('All'));
      expect(picks[0].narratorId, 'sitto');
      expect(picks[1].topic, 'funny_memories');
      expect(picks[2].decade, 1950);
      expect(picks[3].isAll, isTrue);
    });

    testWidgets('the chip row scrolls sideways and never wraps', (t) async {
      await t.pumpApp(_view(AsyncData(_stories)));
      final list = t.widget<ListView>(find.byType(ListView).first);
      expect(list.scrollDirection, Axis.horizontal);
    });

    testWidgets('loading shows skeleton cards', (t) async {
      await t.pumpApp(_view(const AsyncLoading()));
      expect(find.text('Story 1'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('empty offers to record the first story', (t) async {
      var recorded = 0;
      await t.pumpApp(
        _view(const AsyncData(<Story>[]), onRecord: () => recorded++),
      );
      expect(find.text(l10nEn.noStoriesTitle), findsOneWidget);
      await t.tap(find.text(l10nEn.feedRecordFirst));
      expect(recorded, 1);
    });

    testWidgets('error shows Retry', (t) async {
      var retried = 0;
      await t.pumpApp(
        _view(
          const AsyncError<List<Story>>(NetworkFailure(), StackTrace.empty),
          onRetry: () => retried++,
        ),
      );
      await t.tap(find.text(l10nEn.retry));
      expect(retried, 1);
    });
  });
}
