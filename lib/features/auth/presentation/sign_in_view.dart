import 'package:family_stories/core/adaptive/adaptive.dart';
import 'package:family_stories/core/auth/auth_redirect.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/features/auth/presentation/sign_in_page.dart'
    show SignInPage;
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';

enum SignInMode { signIn, signUp }

/// Email + password form, with Apple / Google buttons when they're
/// offered. Pure UI: the form's text and field errors live here, every
/// action goes out through a callback; [SignInPage] does the work.
class SignInView extends StatefulWidget {
  const SignInView({
    required this.onSubmit,
    required this.onForgotPassword,
    required this.onSendLink,
    this.onApple,
    this.onGoogle,
    this.onLocaleChanged,
    this.busy = false,
    this.error,
    this.notice,
    super.key,
  });

  final void Function(SignInMode mode, String email, String password) onSubmit;
  final ValueChanged<String> onForgotPassword;

  /// Emails a sign-in link (no password): the accessible path for older
  /// family members. Shown in sign-in mode only.
  final ValueChanged<String> onSendLink;

  /// Each social button is hidden while its callback is null.
  final VoidCallback? onApple;
  final VoidCallback? onGoogle;

  /// Language switch shown above the form, before anyone is signed in.
  /// Hidden while null.
  final ValueChanged<Locale>? onLocaleChanged;

  /// An action is running: buttons are disabled and a spinner shows.
  final bool busy;

  /// A failure message, or an information (e.g. "check your email").
  final String? error;
  final String? notice;

  @override
  State<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<SignInView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  SignInMode _mode = SignInMode.signIn;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _validEmail() {
    final ok = AuthInput.isEmail(_email.text);
    setState(() => _emailError = ok ? null : context.l10n.authEmailInvalid);
    return ok;
  }

  void _submit() {
    final l10n = context.l10n;
    final emailOk = _validEmail();
    final passwordOk = AuthInput.isPassword(_password.text);
    setState(
      () => _passwordError = passwordOk
          ? null
          : l10n.authPasswordTooShort(AuthInput.passwordMinLength),
    );
    if (emailOk && passwordOk) {
      widget.onSubmit(_mode, _email.text.trim(), _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final signUp = _mode == SignInMode.signUp;
    final enabled = !widget.busy;
    return AppScaffold(
      title: signUp ? l10n.authSignUpTitle : l10n.authSignInTitle,
      body: ListView(
        padding: EdgeInsets.all(AppDimens.xl),
        children: [
          if (widget.onLocaleChanged case final onLocale?) ...[
            _LanguageSwitch(onChanged: onLocale),
            SizedBox(height: AppDimens.lg),
          ],
          TextField(
            key: const Key('sign_in_email'),
            controller: _email,
            enabled: enabled,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            maxLength: AuthInput.emailMaxLength,
            decoration: InputDecoration(
              labelText: l10n.authEmail,
              errorText: _emailError,
              counterText: '',
            ),
          ),
          SizedBox(height: AppDimens.lg),
          TextField(
            key: const Key('sign_in_password'),
            controller: _password,
            enabled: enabled,
            obscureText: true,
            autofillHints: [
              if (signUp) AutofillHints.newPassword else AutofillHints.password,
            ],
            maxLength: AuthInput.passwordMaxLength,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l10n.authPassword,
              errorText: _passwordError,
              counterText: '',
            ),
          ),
          if (widget.error case final error? when error.isNotEmpty) ...[
            SizedBox(height: AppDimens.lg),
            Text(
              error,
              key: const Key('sign_in_error'),
              style: AppTextStyles.body.copyWith(color: scheme.error),
            ),
          ],
          if (widget.notice case final notice?) ...[
            SizedBox(height: AppDimens.lg),
            Text(notice, key: const Key('sign_in_notice')),
          ],
          SizedBox(height: AppDimens.xl),
          AppButton.primary(
            key: const Key('sign_in_submit'),
            wrap: true,
            label: signUp ? l10n.authSignUpButton : l10n.authSignInButton,
            onPressed: enabled ? _submit : null,
            busy: widget.busy,
          ),
          if (!signUp) ...[
            SizedBox(height: AppDimens.sm),
            AppButton.secondary(
              key: const Key('sign_in_send_link'),
              wrap: true,
              label: l10n.authSendLink,
              icon: AdaptiveIcons.mail(context),
              onPressed: enabled
                  ? () {
                      if (_validEmail()) {
                        widget.onSendLink(_email.text.trim());
                      }
                    }
                  : null,
            ),
          ],
          if (!signUp)
            Center(
              child: AppButton.secondary(
                key: const Key('sign_in_forgot'),
                wrap: true,
                label: l10n.authForgotPassword,
                expand: false,
                onPressed: enabled
                    ? () {
                        if (_validEmail()) {
                          widget.onForgotPassword(_email.text.trim());
                        }
                      }
                    : null,
              ),
            ),
          Center(
            child: AppButton.secondary(
              key: const Key('sign_in_switch_mode'),
              wrap: true,
              label: signUp ? l10n.authSwitchToSignIn : l10n.authSwitchToSignUp,
              expand: false,
              onPressed: enabled
                  ? () => setState(
                      () => _mode = signUp
                          ? SignInMode.signIn
                          : SignInMode.signUp,
                    )
                  : null,
            ),
          ),
          if (widget.onApple != null || widget.onGoogle != null) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppDimens.lg),
              child: Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppDimens.sm),
                    child: Text(l10n.authOr),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
            ),
            if (widget.onApple case final onApple?)
              AppButton.secondary(
                key: const Key('sign_in_apple'),
                wrap: true,
                label: l10n.authContinueWithApple,
                icon: AdaptiveIcons.apple,
                onPressed: enabled ? onApple : null,
              ),
            if (widget.onGoogle case final onGoogle?) ...[
              SizedBox(height: AppDimens.sm),
              AppButton.secondary(
                key: const Key('sign_in_google'),
                wrap: true,
                label: l10n.authContinueWithGoogle,
                onPressed: enabled ? onGoogle : null,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Two always-visible language choices. Each name is written in its own
/// language so it can be found without reading the current one.
class _LanguageSwitch extends StatelessWidget {
  const _LanguageSwitch({required this.onChanged});

  final ValueChanged<Locale> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = Localizations.localeOf(context).languageCode;
    return Wrap(
      key: const Key('sign_in_language'),
      spacing: AppDimens.sm,
      runSpacing: AppDimens.sm,
      children: [
        for (final (label, locale) in [
          (l10n.languageEnglish, const Locale('en')),
          (l10n.languageArabic, const Locale('ar')),
        ])
          ChoiceChip(
            label: Text(label),
            selected: current == locale.languageCode,
            onSelected: (_) => onChanged(locale),
          ),
      ],
    );
  }
}
