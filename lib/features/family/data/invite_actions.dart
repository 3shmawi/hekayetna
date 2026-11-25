import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// The platform calls the invite screen makes, behind one seam so tests
/// can check what was sent without a device.
abstract class InviteActions {
  /// Opens `https://wa.me/?text=<text>`. If WhatsApp is not installed the
  /// browser opens it, which is fine. Returns whether anything opened.
  Future<bool> openWhatsApp(String text);

  /// The system share sheet.
  Future<void> share(String text);

  /// Puts [text] on the clipboard.
  Future<void> copy(String text);
}

class PlatformInviteActions implements InviteActions {
  const PlatformInviteActions();

  @override
  Future<bool> openWhatsApp(String text) => launchUrl(
    Uri.https('wa.me', '/', {'text': text}),
    mode: LaunchMode.externalApplication,
  );

  @override
  Future<void> share(String text) =>
      SharePlus.instance.share(ShareParams(text: text)).then((_) {});

  @override
  Future<void> copy(String text) =>
      Clipboard.setData(ClipboardData(text: text));
}

final inviteActionsProvider = Provider<InviteActions>(
  (ref) => const PlatformInviteActions(),
);
