import 'dart:async';

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/analytics/analytics.dart';
import 'package:family_stories/core/auth/auth.dart';
import 'package:family_stories/core/network/result.dart';
import 'package:family_stories/core/ui/app_message.dart';
import 'package:family_stories/core/widgets/state_views.dart';
import 'package:family_stories/features/auth/presentation/account_view.dart';
import 'package:family_stories/features/family/presentation/display_name_dialog.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wires [AccountView] to [Auth]. Signing out or deleting the account
/// makes the router leave this signed-in-only screen by itself.
class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  String _name = '';
  bool _busy = false;
  String? _error;

  Future<void> _run(
    String event,
    Future<Result<void>> Function() action,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final message = appMessenger(context);
    final deletedMessage = context.l10n.accountDeleted;
    final result = await action();
    if (result is Success<void>) {
      unawaited(Analytics.capture(event));
      if (event == 'account_deleted') {
        message(deletedMessage);
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = switch (result) {
        Failed(:final failure) => failure.message(context.l10n),
        Success() => null,
      };
    });
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadName());
  }

  Future<void> _loadName() async {
    final r = await ref.read(familyRepositoryProvider).getMyDisplayName();
    if (!mounted) return;
    if (r case Success(:final value)) setState(() => _name = value);
  }

  Future<void> _editName() async {
    final saved = await showDisplayNameDialog(context, ref, current: _name);
    if (saved != null && mounted) setState(() => _name = saved);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppUser?>(
      valueListenable: Auth.user,
      builder: (context, user, _) => AccountView(
        email: user?.email,
        busy: _busy,
        error: _error,
        displayName: _name,
        onEditName: () => unawaited(_editName()),
        onSignOut: () => unawaited(_run('signed_out', Auth.service.signOut)),
        onDelete: () =>
            unawaited(_run('account_deleted', Auth.service.deleteAccount)),
      ),
    );
  }
}
