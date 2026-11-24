import 'package:family_stories/core/network/app_failure.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/player/audio_player_controller.dart';
import 'package:family_stories/features/stories/presentation/story_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

final Story _story = Story(
  id: 's1',
  spaceId: 'sp',
  title: 'The first Om Ali',
  description: 'Sitto remembers the first pan.',
  topic: 'ramadan_eid_traditions',
  approxDateLabel: 'Ramadan, late 1950s',
  visibility: StoryVisibility.family,
  audioPath: 'a/b.wav',
  durationSeconds: 154,
  createdBy: 'me',
  createdAt: DateTime(2026),
);

Widget _view({
  bool creator = true,
  PlayerState player = const PlayerState(),
  ValueChanged<StoryMenuAction>? onMenu,
  VoidCallback? onToggle,
  VoidCallback? onSpeed,
}) => StoryView(
  story: _story,
  player: player,
  narratorName: 'Sitto',
  recordedBy: 'Recorded by Mona',
  isCreator: creator,
  visibilityNote: 'The whole family can hear this (8 people)',
  onToggle: onToggle ?? () {},
  onSeek: (_) {},
  onSpeed: onSpeed ?? () {},
  onMenu: onMenu ?? (_) {},
);

void main() {
  testWidgets('shows title, date, narrator, description and note', (t) async {
    await t.pumpApp(_view());
    expect(find.text('The first Om Ali'), findsOneWidget);
    expect(find.text('Ramadan, late 1950s · Recorded by Mona'), findsOneWidget);
    expect(find.text('Told by Sitto'), findsOneWidget);
    expect(find.text('Sitto remembers the first pan.'), findsOneWidget);
    expect(
      find.text('The whole family can hear this (8 people)'),
      findsOneWidget,
    );
    expect(find.text('2:34'), findsOneWidget);
    expect(find.text('1×'), findsOneWidget);
  });

  testWidgets('the creator sees More with Edit, Who can listen, Delete', (
    t,
  ) async {
    final picked = <StoryMenuAction>[];
    await t.pumpApp(_view(onMenu: picked.add));
    await t.tap(find.byTooltip(l10nEn.storyMore));
    await t.pumpAndSettle();
    expect(find.text(l10nEn.storyEditDetails), findsOneWidget);
    expect(find.text(l10nEn.storyWhoCanListen), findsWidgets);
    await t.tap(find.text(l10nEn.storyDelete));
    expect(picked, [StoryMenuAction.delete]);
  });

  testWidgets('a listener sees no More menu and no lock', (t) async {
    await t.pumpApp(_view(creator: false));
    expect(find.byTooltip(l10nEn.storyMore), findsNothing);
    expect(find.byTooltip(l10nEn.storyWhoCanListen), findsNothing);
  });

  testWidgets('play and speed call back; the player state drives the card', (
    t,
  ) async {
    var toggled = 0;
    var sped = 0;
    await t.pumpApp(
      _view(
        onToggle: () => toggled++,
        onSpeed: () => sped++,
        player: const PlayerState(
          storyId: 's1',
          status: PlayerStatus.playing,
          position: Duration(seconds: 72),
          duration: Duration(seconds: 154),
          speed: 1.5,
        ),
      ),
    );
    expect(find.text('1:12'), findsOneWidget);
    expect(find.text('1.5×'), findsOneWidget);
    await t.tap(find.byTooltip(l10nEn.storyPause));
    await t.tap(find.text('1.5×'));
    expect(toggled, 1);
    expect(sped, 1);
  });

  testWidgets('another story playing does not move this card', (t) async {
    await t.pumpApp(
      _view(
        player: const PlayerState(
          storyId: 'other',
          status: PlayerStatus.playing,
          position: Duration(seconds: 90),
        ),
      ),
    );
    expect(find.byTooltip(l10nEn.storyPlay), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);
  });

  testWidgets('not-shared and error states', (t) async {
    await t.pumpApp(const StoryStateView.notShared());
    expect(find.text(l10nEn.storyNotShared), findsOneWidget);
    var retried = 0;
    await t.pumpApp(
      StoryStateView.error(
        failure: const NetworkFailure(),
        onRetry: () => retried++,
      ),
    );
    await t.tap(find.text(l10nEn.retry));
    expect(retried, 1);
  });
}
