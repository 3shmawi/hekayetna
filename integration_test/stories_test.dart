import 'package:family_stories/features/stories/presentation/mini_player.dart';
import 'package:family_stories/features/stories/presentation/story_feed_page.dart';
import 'package:family_stories/features/stories/presentation/story_page.dart';
import 'package:family_stories/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/demo.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Spec 03 AC-9, in demo mode: filter by Sitto, open the story, play,
  // change speed, go back and see the mini player.
  testWidgets('filter, open, play, change speed, back, mini player', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();
    await skipFirstLaunch(tester);
    await beat(tester, 1500);
    expect(find.byType(StoryFeedPage), findsOneWidget);

    await tester.tap(find.text('Sitto Amina (sample)').first);
    await tester.pumpAndSettle();
    await beat(tester);

    await tester.tap(find.textContaining('The first Om Ali').first);
    await tester.pumpAndSettle();
    expect(find.byType(StoryPage), findsOneWidget);
    await beat(tester);

    await tester.tap(find.byTooltip('Play story'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('1×'));
    await tester.pumpAndSettle();
    expect(find.text('1×'), findsNothing);
    await beat(tester);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(MiniPlayer), findsOneWidget);
    await beat(tester, 1500);
  });
}
