import 'package:family_stories/features/family/presentation/family_tree_canvas.dart';
import 'package:family_stories/features/recording/presentation/record_page.dart';
import 'package:family_stories/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/demo.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Spec 05 AC-11, in demo mode (NOT RUN yet: needs a device or simulator):
  // open Family, zoom out, fit, tap Sitto, play all, close, long-press
  // Mama, Record with.
  testWidgets('tree: zoom, fit, person sheet, play all, long-press record', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();
    await skipFirstLaunch(tester);
    await tester.tap(find.text('Family').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tree'));
    await tester.pumpAndSettle();
    expect(find.byType(FamilyTreeCanvas), findsOneWidget);
    await beat(tester);

    await tester.tap(find.byTooltip('Zoom out'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show the whole family'));
    await tester.pumpAndSettle();
    await beat(tester);

    await tester.tap(find.textContaining('Sitto Amina').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play all'));
    await tester.pumpAndSettle();
    await beat(tester);

    await tester.longPress(find.textContaining('Mama').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Record'));
    await tester.pumpAndSettle();
    expect(find.byType(RecordPage), findsOneWidget);
    await beat(tester, 1500);
  });
}
