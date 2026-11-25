import 'dart:async';

import 'package:family_stories/core/auth/auth.dart';
import 'package:family_stories/core/auth/auth_redirect.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/core/router/app_routes.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/core/ui/app_message.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/core/ui/auth_chrome.dart';
import 'package:family_stories/core/widgets/state_views.dart';
import 'package:family_stories/features/settings/presentation/settings_controller.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Shown after the user opens a password-reset link (Supabase; Firebase
/// sets the password on its own web page).
class NewPasswordPage extends ConsumerStatefulWidget {
  const NewPasswordPage({super.key});

  @override
  ConsumerState<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends ConsumerState<NewPasswordPage> {
  final _password = TextEditingController();
  bool _busy = false;
  bool _show = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!AuthInput.isPassword(_password.text)) {
      setState(
        () => _error = l10n.authPasswordTooShort(AuthInput.passwordMinLength),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final message = appMessenger(context);
    final result = await Auth.service.updatePassword(_password.text);
    if (!mounted) return;
    switch (result) {
      case Success():
        message(l10n.newPasswordSaved);
        context.go(AppRoutes.home);
      case Failed(:final failure):
        setState(() {
          _busy = false;
          _error = failure.message(l10n);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AuthTheme(
      child: Builder(
        builder: (context) => AppScaffold(
          background: AuthPalette.of(context).background,
          body: ListView(
            padding: EdgeInsets.all(AppDimens.xl),
            children: [
              const AuthEmblem(),
              SizedBox(height: AppDimens.xl),
              AuthLanguageSwitch(
                onChanged: ref
                    .read(settingsControllerProvider.notifier)
                    .setLocale,
              ),
              SizedBox(height: AppDimens.xl),
              AuthHeading(l10n.newPasswordTitle),
              SizedBox(height: AppDimens.lg),
              AuthField(
                fieldKey: const Key('new_password_field'),
                label: l10n.authPassword,
                icon: Icons.lock_outline_rounded,
                controller: _password,
                enabled: !_busy,
                obscureText: !_show,
                autofillHints: const [AutofillHints.newPassword],
                maxLength: AuthInput.passwordMaxLength,
                onSubmitted: (_) => unawaited(_save()),
                trailing: AuthVisibilityToggle(
                  visible: _show,
                  onChanged: (v) => setState(() => _show = v),
                ),
              ),
              if (_error case final error?) ...[
                SizedBox(height: AppDimens.lg),
                Text(
                  error,
                  style: AppTextStyles.body.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              SizedBox(height: AppDimens.xl),
              AppButton.primary(
                key: const Key('new_password_save'),
                label: l10n.newPasswordSave,
                busy: _busy,
                onPressed: () => unawaited(_save()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
