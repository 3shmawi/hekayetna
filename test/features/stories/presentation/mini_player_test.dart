import 'package:family_stories/features/stories/presentation/mini_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  group('shouldShowMiniPlayer', () {
    test('hidden when nothing plays', () {
      expect(
        shouldShowMiniPlayer(storyId: null, location: '/stories'),
        isFalse,
      );
    });
    test('hidden on the own page of the playing story', () {
      expect(
        shouldShowMiniPlayer(storyId: 'a', location: '/stories/a'),
        isFalse,
      );
    });
    test('shown on the feed, another story or another tab', () {
      for (final loc in ['/stories', '/stories/b', '/family', '/record']) {
        expect(shouldShowMiniPlayer(storyId: 'a', location: loc), isTrue);
      }
    });
  });

  testWidgets('shows the title, toggles and opens the story', (t) async {
    var toggled = 0;
    var opened = 0;
    await t.pumpApp(
      Align(
        alignment: Alignment.bottomCenter,
        child: MiniPlayer(
          title: 'The first Om Ali',
          isPlaying: true,
          progress: 0.4,
          onToggle: () => toggled++,
          onOpen: () => opened++,
        ),
      ),
    );
    expect(find.text('The first Om Ali'), findsOneWidget);
    await t.tap(find.byTooltip(l10nEn.storyPause));
    await t.tap(find.text('The first Om Ali'));
    expect(toggled, 1);
    expect(opened, 1);
  });
}
