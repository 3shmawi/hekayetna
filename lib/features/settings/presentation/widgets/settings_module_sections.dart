import 'dart:async';

import 'package:family_stories/core/adaptive/adaptive.dart';
import 'package:family_stories/core/auth/auth.dart';
import 'package:family_stories/core/privacy/consent.dart';
import 'package:family_stories/core/privacy/consent_sheet.dart';
import 'package:family_stories/core/router/app_routes.dart';
import 'package:family_stories/features/settings/presentation/widgets/settings_tiles.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Settings groups that wire themselves to a service: the project's modules
/// (sign-in, paid features, notifications) and Privacy. The settings page
/// stays the same whatever modules the app has.
class SettingsModuleSections extends StatelessWidget {
  const SettingsModuleSections({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionHeader(l10n.settingsAccount),
        SettingsGroup(
          children: [
            ValueListenableBuilder<AppUser?>(
              valueListenable: Auth.user,
              builder: (context, user, _) => SettingsRow(
                key: const Key('settings_account'),
                label: user == null ? l10n.settingsSignIn : l10n.accountTitle,
                value: user?.email,
                icon: AdaptiveIcons.account(context),
                onTap: () => unawaited(
                  context.push<void>(
                    user == null ? AppRoutes.signIn : AppRoutes.account,
                  ),
                ),
              ),
            ),
          ],
        ),
        // Only when an analytics SDK is set up in the env file.
        if (ConsentListener.isNeeded) ...[
          SettingsSectionHeader(l10n.settingsPrivacySection),
          SettingsGroup(
            children: [
              ValueListenableBuilder<ConsentChoice>(
                valueListenable: Consent.analytics,
                builder: (context, choice, _) => SettingsSwitchRow(
                  key: const Key('settings_usage_data'),
                  label: l10n.settingsUsageData,
                  subtitle: l10n.settingsUsageDataHelp,
                  icon: AdaptiveIcons.privacy(context),
                  value: choice == ConsentChoice.granted,
                  onChanged: (on) => unawaited(
                    Consent.set(
                      on ? ConsentChoice.granted : ConsentChoice.denied,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
