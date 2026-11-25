import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// True when recording a demo video (`--dart-define=DEMO=true`).
const isDemo = bool.fromEnvironment('DEMO');

/// A short pause between steps so a recorded demo is easy to follow.
/// Does nothing in normal test runs, so CI stays fast.
Future<void> beat(WidgetTester tester, [int milliseconds = 900]) async {
  if (!isDemo) return;
  await tester.pump(Duration(milliseconds: milliseconds));
  await Future<void>.delayed(Duration(milliseconds: milliseconds));
}

/// Gets past first-launch screens so every flow starts on home: the
/// welcome pages (onboarding module) and the usage-data question (only
/// shown when the env file has an analytics key). Call it right after
/// `app.main()` + `pumpAndSettle()`.
Future<void> skipFirstLaunch(WidgetTester tester) async {
  for (final key in ['onboarding_skip', 'consent_deny']) {
    final button = find.byKey(Key(key));
    if (button.evaluate().isEmpty) continue;
    await tester.tap(button);
    await tester.pumpAndSettle();
  }
}

/// Runs [body] and always puts the test binding's error handlers back
/// afterwards, even when [body] fails. The app's error monitoring replaces
/// `FlutterError.onError` and `PlatformDispatcher.onError`; if a failing
/// test left them replaced, the binding asserted and the harness waited
/// instead of reporting the failure. The failure itself still propagates.
Future<void> restoringErrorHandlers(Future<void> Function() body) async {
  final originalOnError = FlutterError.onError;
  final originalPlatformOnError = PlatformDispatcher.instance.onError;
  try {
    await body();
  } finally {
    FlutterError.onError = originalOnError;
    PlatformDispatcher.instance.onError = originalPlatformOnError;
  }
}
