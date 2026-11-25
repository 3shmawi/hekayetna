import 'package:family_stories/features/auth/presentation/sign_in_view.dart';
import 'package:family_stories/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/demo.dart';

/// Settings → Account → the sign-in screen, and the form's checks. Signing
/// in for real needs the backend in the env file; this flow doesn't.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opens sign-in from settings and checks the email', (
    tester,
  ) async {
    debugPrint('[it] before app.main');
    await app.main();
    debugPrint('[it] app.main returned');
    await tester.pumpAndSettle();
    debugPrint('[it] first pumpAndSettle done');
    await skipFirstLaunch(tester);
    await beat(tester);

    await tester.tap(find.byKey(const Key('home_settings_button')));
    await tester.pumpAndSettle();
    await beat(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('settings_account')),
      200,
    );
    await tester.tap(find.byKey(const Key('settings_account')));
    await tester.pumpAndSettle();
    expect(find.byType(SignInView), findsOneWidget);
    await beat(tester);

    await tester.enterText(
      find.byKey(const Key('sign_in_email')),
      'not-an-email',
    );
    await beat(tester);
    await tester.tap(find.byKey(const Key('sign_in_submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sign_in_email')), findsOneWidget);
    await beat(tester, 1500);
  });
}
