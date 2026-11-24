import 'dart:async';

import 'package:family_stories/core/analytics/analytics.dart';
import 'package:family_stories/core/auth/auth.dart';
import 'package:family_stories/core/network/app_failure.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/core/widgets/state_views.dart';
import 'package:family_stories/features/auth/presentation/sign_in_view.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/widgets.dart';

/// Wires [SignInView] to [Auth.service]. After a successful sign-in the
/// router's redirect leaves this screen by itself (core/auth/auth_redirect.dart).
class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  bool _busy = false;
  String? _error;
  String? _notice;

  AuthService get _auth => Auth.service;

  Future<void> _run(
    String method,
    Future<Result<Object?>> Function() action, {
    String? notice,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    final result = await action();
    if (!mounted) return;
    final l10n = context.l10n;
    setState(() {
      _busy = false;
      result.fold(
        onSuccess: (value) {
          _notice = value == SignUpOutcome.confirmEmail
              ? l10n.authConfirmEmailSent
              : notice;
          unawaited(Analytics.capture('auth_succeeded', {'method': method}));
        },
        onFailure: (failure) {
          // A closed Apple / Google sheet isn't an error.
          if (failure case AuthFailure(reason: AuthFailureReason.cancelled)) {
            return;
          }
          _error = failure.message(l10n);
          unawaited(Analytics.capture('auth_failed', {'method': method}));
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SignInView(
      busy: _busy,
      error: _error,
      notice: _notice,
      onSubmit: (mode, email, password) => unawaited(
        mode == SignInMode.signUp
            ? _run(
                'email_sign_up',
                () => _auth.signUpWithEmail(email: email, password: password),
              )
            : _run(
                'email',
                () => _auth.signInWithEmail(email: email, password: password),
              ),
      ),
      onForgotPassword: (email) => unawaited(
        _run(
          'password_reset',
          () => _auth.sendPasswordReset(email),
          notice: context.l10n.authResetSent,
        ),
      ),
      onSendLink: (email) => unawaited(
        _run(
          'sign_in_link',
          () => _auth.sendSignInLink(email),
          notice: context.l10n.authLinkSent,
        ),
      ),
      onApple: _auth.canUseApple
          ? () => unawaited(_run('apple', _auth.signInWithApple))
          : null,
      onGoogle: _auth.canUseGoogle
          ? () => unawaited(_run('google', _auth.signInWithGoogle))
          : null,
    );
  }
}
