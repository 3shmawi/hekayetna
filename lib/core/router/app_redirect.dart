import 'package:family_stories/core/auth/auth.dart';
import 'package:family_stories/core/auth/auth_redirect.dart';
import 'package:family_stories/core/backend/backend.dart';
import 'package:family_stories/features/onboarding/data/onboarding.dart';
import 'package:flutter/foundation.dart';

/// Every app-wide redirect, in order (first match wins). The router calls
/// this on each navigation and again when [redirectChanges] fires.
String? appRedirect(Uri uri) {
  final onboarding = onboardingRedirect(uri, seen: Onboarding.seen.value);
  if (onboarding != null) return onboarding;
  return authRedirect(
    uri,
    // Demo mode (no backend configured) keeps every path reachable so the
    // app stays explorable on its in-memory repositories.
    signedIn:
        Auth.isSignedIn || (demoModeSignedInOverride ?? !Backend.isConfigured),
    passwordRecovery: Auth.passwordRecovery.value,
  );
}

/// Test hook: forces the demo-mode bypass on/off. Null (the default)
/// derives it from [Backend.isConfigured].
bool? demoModeSignedInOverride;

/// What [appRedirect] depends on.
Listenable get redirectChanges =>
    Listenable.merge([Auth.changes, Onboarding.seen]);
