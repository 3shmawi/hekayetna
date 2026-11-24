import 'package:family_stories/core/router/not_found_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  group(NotFoundPage, () {
    testWidgets('explains the problem and offers a way home', (tester) async {
      await tester.pumpApp(const NotFoundPage());

      expect(find.text(l10nEn.notFoundTitle), findsOneWidget);
      expect(find.text(l10nEn.notFoundGoHome), findsOneWidget);
    });

    testWidgets('meets accessibility guidelines', (tester) async {
      await tester.pumpApp(const NotFoundPage());
      await tester.expectAccessible();
    });
  });
}
