import 'dart:async';

import 'package:family_stories/core/adaptive/adaptive.dart';
import 'package:family_stories/core/analytics/analytics.dart';
import 'package:family_stories/core/theme/app_colors.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/core/ui/app_message.dart';
import 'package:family_stories/features/family/data/invite_actions.dart';
import 'package:family_stories/features/family/domain/invite_code.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Invite family: a QR code for the table, WhatsApp, the share sheet and a
/// short code to copy. The owner can change the code.
class InvitePage extends ConsumerStatefulWidget {
  const InvitePage({
    required this.familyName,
    required this.shortCode,
    required this.isOwner,
    required this.onRotate,
    this.webHost,
    this.from = 'unknown',
    super.key,
  });

  final String familyName;
  final ShortInviteCode shortCode;
  final bool isOwner;

  /// Owner only. Returns the new short code, or null if it failed.
  final Future<ShortInviteCode?> Function() onRotate;

  /// The verified website host, if any. Null until the domain is verified,
  /// then links use `https://<host>/join/<code>`.
  final String? webHost;

  /// Where the page was opened from, for analytics.
  final String from;

  @override
  ConsumerState<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends ConsumerState<InvitePage> {
  late ShortInviteCode _code = widget.shortCode;

  @override
  void initState() {
    super.initState();
    unawaited(Analytics.capture('invite_opened', {'from': widget.from}));
    unawaited(Analytics.capture('invite_shared', {'via': 'qr_shown'}));
  }

  /// The link in the QR code and the messages. A verified web link wins
  /// once configured; the app scheme works now.
  String get link =>
      InviteLinks.webLink(_code, host: widget.webHost) ??
      InviteLinks.deepLink(_code);

  String _message(BuildContext context) =>
      context.l10n.inviteMessage(link, _code.display);

  Future<void> _rotate() async {
    final l10n = context.l10n;
    final say = appMessenger(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.inviteChangeConfirmTitle),
        content: Text(l10n.inviteChangeConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n.inviteChangeConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final next = await widget.onRotate();
    if (!mounted) return;
    if (next == null) {
      say(l10n.errorUnknown);
      return;
    }
    setState(() => _code = next);
    unawaited(Analytics.capture('invite_code_rotated'));
    say(l10n.inviteCodeChanged);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final actions = ref.read(inviteActionsProvider);
    final say = appMessenger(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.inviteTitle),
        actions: [
          if (widget.isOwner)
            PopupMenuButton<int>(
              tooltip: l10n.inviteMore,
              icon: Icon(AdaptiveIcons.more(context)),
              onSelected: (_) => unawaited(_rotate()),
              itemBuilder: (_) => [
                PopupMenuItem(value: 0, child: Text(l10n.inviteChangeCode)),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(AppDimens.lg),
          children: [
            Text(
              l10n.inviteScanHint(widget.familyName),
              style: AppTextStyles.body,
            ),
            SizedBox(height: AppDimens.lg),
            Center(
              // A white tile with dark modules even in dark mode: scanners
              // need the contrast.
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                ),
                child: QrImageView(
                  data: link,
                  size: 220,
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.white,
                  semanticsLabel: l10n.inviteQrSemantics,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppColors.ink,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
            SizedBox(height: AppDimens.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Semantics(
                  label: l10n.inviteCodeLabel,
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      _code.display,
                      style: AppTextStyles.title.copyWith(letterSpacing: 2),
                    ),
                  ),
                ),
                SizedBox(width: AppDimens.md),
                TextButton(
                  onPressed: () {
                    unawaited(actions.copy(_code.value));
                    unawaited(
                      Analytics.capture('invite_shared', {'via': 'copy'}),
                    );
                    say(l10n.inviteCodeCopied);
                  },
                  child: Text(l10n.inviteCopy),
                ),
              ],
            ),
            SizedBox(height: AppDimens.lg),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.whatsapp,
                foregroundColor: Colors.white,
                minimumSize: Size.fromHeight(AppDimens.targetMin),
              ),
              onPressed: () {
                unawaited(actions.openWhatsApp(_message(context)));
                unawaited(
                  Analytics.capture('invite_shared', {'via': 'whatsapp'}),
                );
              },
              child: Text(l10n.inviteSendWhatsApp),
            ),
            SizedBox(height: AppDimens.sm),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: Size.fromHeight(AppDimens.targetMin),
              ),
              onPressed: () {
                unawaited(actions.share(_message(context)));
                unawaited(Analytics.capture('invite_shared', {'via': 'share'}));
              },
              child: Text(l10n.inviteShareOther),
            ),
            SizedBox(height: AppDimens.lg),
            Text(
              l10n.inviteFooter,
              style: AppTextStyles.caption.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
