import 'package:family_stories/features/family/domain/family_graph.dart';
import 'package:family_stories/features/family/presentation/person_sheet.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/player/audio_player_controller.dart';
import 'package:family_stories/features/stories/presentation/story_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';
import '../domain/family_fixtures.dart';

Story _story(String id, String narrator, String? topic) => Story(
  id: id,
  spaceId: 's',
  title: 'Story $id',
  visibility: StoryVisibility.family,
  audioPath: 'p/$id.wav',
  durationSeconds: 120,
  createdBy: 'u',
  createdAt: DateTime(2026),
  narratorIds: [narrator],
  topic: topic,
);

class _Feed extends StoryFeedNotifier {
  _Feed(super.filter);
  @override
  Future<List<Story>> build() async => [
    _story('a', 'sitto', 'funny_memories'),
    _story('b', 'sitto', 'life_events'),
    _story('c', 'sitto', 'funny_memories'),
    _story('d', 'sitto', 'funny_memories'),
    _story('e', 'mama', null),
  ];
}

class _Player extends AudioPlayerController {
  static final queued = <String>[];
  static final played = <String>[];
  @override
  PlayerState build() => const PlayerState();
  @override
  Future<void> playQueue(List<Story> stories) async =>
      queued.addAll(stories.map((s) => s.id));
  @override
  Future<void> playStory(Story story) async => played.add(story.id);
}

void main() {
  late FamilyGraph graph;
  setUp(() {
    _Player.queued.clear();
    _Player.played.clear();
    final fam = bigFamily();
    graph = FamilyGraph.build(
      persons: fam.persons,
      relationships: fam.rels,
      meId: 'me',
      storiesByNarrator: {
        'sitto': [120, 120, 120, 120],
      },
    );
  });

  Widget host(Future<Object?> Function(BuildContext) open) => ProviderScope(
    overrides: [
      storyFeedProvider.overrideWith2(_Feed.new),
      audioPlayerControllerProvider.overrideWith(_Player.new),
    ],
    child: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => open(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  Widget sheet() => ProviderScope(
    overrides: [
      storyFeedProvider.overrideWith2(_Feed.new),
      audioPlayerControllerProvider.overrideWith(_Player.new),
    ],
    child: Scaffold(
      body: PersonSheet(graph: graph, personId: 'sitto'),
    ),
  );

  testWidgets('Play all queues the right stories', (t) async {
    await t.pumpApp(sheet());
    await t.pumpAndSettle();
    expect(find.text('Play all'), findsOneWidget);
    await t.tap(find.text('Play all'));
    await t.pumpAndSettle();
    expect(_Player.queued, ['a', 'b', 'c', 'd']);
  });

  testWidgets('topic chips filter the voices and See all offers the rest', (
    t,
  ) async {
    await t.pumpApp(sheet());
    await t.pumpAndSettle();
    expect(find.text('See all 4'), findsOneWidget);
    await t.tap(find.textContaining('Important life events'));
    await t.pumpAndSettle();
    expect(find.text('Story b'), findsOneWidget);
    expect(find.text('Story a'), findsNothing);
    expect(find.textContaining('See all'), findsNothing);
  });

  testWidgets('the long-press menu has exactly three actions', (t) async {
    await t.pumpApp(host((c) => showPersonQuickMenu(c, name: 'Hany')));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.byType(ListTile), findsNWidgets(3));
    expect(find.text('Record Hany'), findsOneWidget);
    expect(find.text('Add a relative'), findsOneWidget);
    expect(find.text('Edit person'), findsOneWidget);
  });
}
