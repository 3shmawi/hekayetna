import 'dart:async';

import 'package:family_stories/core/auth/auth.dart';
import 'package:family_stories/core/backend/backend.dart';
import 'package:family_stories/core/network/app_failure.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// [AuthService] on Supabase Auth. Account deletion runs in the
/// `delete-account` Edge Function (supabase/functions/), because only the
/// server may delete users; rows that reference `auth.users` with
/// `on delete cascade` (e.g. `profiles`) go with it.
class BackendAuthService implements AuthService {
  BackendAuthService();

  /// Where reset and confirmation links send the user back to: the app's
  /// own scheme. Add it in Supabase → Authentication → URL Configuration →
  /// Redirect URLs (docs/features/auth.md).
  static const redirectUrl = 'familystories://auth-callback';

  StreamSubscription<AuthState>? _subscription;

  GoTrueClient get _auth => Backend.client.auth;

  @override
  Future<void> start() async {
    if (!Backend.isConfigured) return;
    Auth.user.value = _toUser(_auth.currentUser);
    _subscription ??= _auth.onAuthStateChange.listen((state) {
      Auth.user.value = _toUser(state.session?.user);
      if (state.event == AuthChangeEvent.passwordRecovery) {
        Auth.passwordRecovery.value = true;
      }
    });
  }

  @override
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  static AppUser? _toUser(User? user) =>
      user == null ? null : AppUser(id: user.id, email: user.email);

  Future<Result<T>> _call<T>(Future<T> Function() action) {
    if (!Backend.isConfigured) {
      return Future.value(
        const Failed(AuthFailure(AuthFailureReason.notConfigured)),
      );
    }
    // Wrong passwords are not worth retrying.
    return guard(action, retries: 0);
  }

  @override
  Future<Result<void>> signInWithEmail({
    required String email,
    required String password,
  }) => _call(
    () => _auth.signInWithPassword(email: email.trim(), password: password),
  );

  @override
  Future<Result<SignUpOutcome>> signUpWithEmail({
    required String email,
    required String password,
  }) => _call(() async {
    final response = await _auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: redirectUrl,
    );
    return response.session == null
        ? SignUpOutcome.confirmEmail
        : SignUpOutcome.signedIn;
  });

  @override
  Future<Result<void>> sendPasswordReset(String email) => _call(
    () => _auth.resetPasswordForEmail(email.trim(), redirectTo: redirectUrl),
  );

  @override
  Future<Result<void>> sendSignInLink(String email) => _call(
    () =>
        _auth.signInWithOtp(email: email.trim(), emailRedirectTo: redirectUrl),
  );

  @override
  Future<Result<void>> updatePassword(String password) => _call(() async {
    await _auth.updateUser(UserAttributes(password: password));
    Auth.passwordRecovery.value = false;
  });

  @override
  bool get canUseApple => false;

  @override
  Future<Result<void>> signInWithApple() async =>
      const Failed(AuthFailure(AuthFailureReason.notConfigured));

  @override
  bool get canUseGoogle => false;

  @override
  Future<Result<void>> signInWithGoogle() async =>
      const Failed(AuthFailure(AuthFailureReason.notConfigured));

  @override
  Future<Result<void>> signOut() => _call(() async {
    await _auth.signOut();
  });

  @override
  Future<Result<void>> deleteAccount() => _call(() async {
    final response = await Backend.client.functions.invoke('delete-account');
    if (response.status != 200) {
      throw ServerFailure('delete-account returned ${response.status}');
    }
    // The session's user no longer exists: clear it locally.
    await _auth.signOut();
  });
}
