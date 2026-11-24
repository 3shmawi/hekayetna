import 'package:family_stories/core/adaptive/adaptive.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/features/settings/presentation/widgets/settings_tiles.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The signed-in account: who, sign out, delete account. Pure UI.
class AccountView extends StatelessWidget {
  const AccountView({
    required this.email,
    required this.onSignOut,
    required this.onDelete,
    this.busy = false,
    this.error,
    super.key,
  });

  final String? email;
  final VoidCallback onSignOut;

  /// Called after the user confirmed in the dialog.
  final VoidCallback onDelete;
  final bool busy;
  final String? error;

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text(l10n.accountDeleteTitle),
        content: Text(l10n.accountDeleteMessage),
        actions: [
          AdaptiveDialogAction(
            key: const Key('account_delete_cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            isDefault: true,
            child: Text(l10n.accountCancel),
          ),
          AdaptiveDialogAction(
            key: const Key('account_delete_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            isDestructive: true,
            child: Text(l10n.accountDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return AppScaffold(
      title: l10n.accountTitle,
      body: ListView(
        padding: EdgeInsetsDirectional.fromSTEB(
          AppDimens.lg,
          0,
          AppDimens.lg,
          AppDimens.xxl,
        ),
        children: [
          SettingsSectionHeader(l10n.accountSignedInAs),
          SettingsGroup(
            children: [
              SettingsRow(
                key: const Key('account_email'),
                label: email ?? '—',
                icon: AdaptiveIcons.account(context),
              ),
            ],
          ),
          SizedBox(height: AppDimens.xl),
          SettingsGroup(
            children: [
              SettingsRow(
                key: const Key('account_sign_out'),
                label: l10n.accountSignOut,
                icon: AdaptiveIcons.signOut(context),
                onTap: busy ? null : onSignOut,
              ),
              SettingsRow(
                key: const Key('account_delete'),
                label: l10n.accountDelete,
                icon: AdaptiveIcons.delete(context),
                onTap: busy ? null : () => _confirmDelete(context),
              ),
            ],
          ),
          if (busy) ...[
            SizedBox(height: AppDimens.xl),
            const Center(child: CircularProgressIndicator.adaptive()),
          ],
          if (error case final error? when error.isNotEmpty) ...[
            SizedBox(height: AppDimens.lg),
            Text(
              error,
              key: const Key('account_error'),
              style: AppTextStyles.body.copyWith(color: scheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
