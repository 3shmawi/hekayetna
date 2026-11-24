import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Platform-adaptive building blocks: Cupertino look on iOS/macOS,
/// Material on Android. Prefer Flutter's own `.adaptive` constructors
/// (`Switch.adaptive`, `AlertDialog.adaptive`,
/// `CircularProgressIndicator.adaptive`, `showAdaptiveDialog`) and these
/// widgets over platform checks inside feature code.
extension AdaptivePlatform on BuildContext {
  bool get isCupertino {
    final platform = Theme.of(this).platform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  }
}

/// Primary call-to-action button.
class AdaptiveButton extends StatelessWidget {
  const AdaptiveButton({
    required this.onPressed,
    required this.child,
    super.key,
  });

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.isCupertino) {
      return CupertinoButton.filled(onPressed: onPressed, child: child);
    }
    return FilledButton(onPressed: onPressed, child: child);
  }
}

/// An action button for `AlertDialog.adaptive`.
class AdaptiveDialogAction extends StatelessWidget {
  const AdaptiveDialogAction({
    required this.onPressed,
    required this.child,
    this.isDefault = false,
    this.isDestructive = false,
    super.key,
  });

  final VoidCallback onPressed;
  final Widget child;
  final bool isDefault;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    if (context.isCupertino) {
      return CupertinoDialogAction(
        onPressed: onPressed,
        isDefaultAction: isDefault,
        isDestructiveAction: isDestructive,
        child: child,
      );
    }
    final color = isDestructive ? Theme.of(context).colorScheme.error : null;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: color),
      child: child,
    );
  }
}

/// Adaptive icons for the few icons that differ between platforms.
abstract final class AdaptiveIcons {
  static IconData settings(BuildContext context) =>
      context.isCupertino ? CupertinoIcons.settings : Icons.settings_outlined;

  static IconData check(BuildContext context) =>
      context.isCupertino ? CupertinoIcons.check_mark : Icons.check;

  static IconData back(BuildContext context) =>
      context.isCupertino ? CupertinoIcons.back : Icons.arrow_back;

  /// "Opens something" chevron at a row's end. Mirrors in RTL (points to
  /// the end edge in Arabic too), like iOS; `CupertinoIcons.forward`
  /// itself doesn't mirror.
  static IconData forward(BuildContext context) =>
      context.isCupertino ? _cupertinoForward : Icons.chevron_right;

  @visibleForTesting
  static const IconData forwardForTest = _cupertinoForward;

  static const IconData _cupertinoForward = IconData(
    0xf3d1,
    fontFamily: CupertinoIcons.iconFont,
    fontPackage: CupertinoIcons.iconFontPackage,
    matchTextDirection: true,
  );

  // Settings rows: SF Symbols' look on iOS, Material outlines on Android.
  static IconData language(BuildContext context) =>
      context.isCupertino ? CupertinoIcons.globe : Icons.translate;

  static IconData theme(BuildContext context) => context.isCupertino
      ? CupertinoIcons.circle_lefthalf_fill
      : Icons.contrast;

  static IconData privacy(BuildContext context) => context.isCupertino
      ? CupertinoIcons.hand_raised
      : Icons.privacy_tip_outlined;

  static IconData terms(BuildContext context) =>
      context.isCupertino ? CupertinoIcons.doc_text : Icons.gavel_outlined;

  static IconData licenses(BuildContext context) => context.isCupertino
      ? CupertinoIcons.doc_on_doc
      : Icons.description_outlined;

  static IconData info(BuildContext context) =>
      context.isCupertino ? CupertinoIcons.info_circle : Icons.info_outline;

  /// The update sheet / forced-update screen.
  static IconData update(BuildContext context) => context.isCupertino
      ? CupertinoIcons.arrow_down_circle
      : Icons.system_update_outlined;

  static IconData account(BuildContext context) => context.isCupertino
      ? CupertinoIcons.person_crop_circle
      : Icons.account_circle_outlined;

  static IconData signOut(BuildContext context) =>
      context.isCupertino ? CupertinoIcons.square_arrow_right : Icons.logout;

  static IconData delete(BuildContext context) =>
      context.isCupertino ? CupertinoIcons.delete : Icons.delete_outline;

  /// Apple's logo for "Continue with Apple" (same on both platforms).
  static const IconData apple = Icons.apple;

  static IconData mail(BuildContext context) =>
      context.isCupertino ? CupertinoIcons.mail : Icons.mail_outline;

  // Hekayetna (design foundation, spec 01): SF Symbol look on iOS,
  // Material outlined on Android. Icons are 24px, ink or ink-soft; only
  // the record icon is terracotta.

  /// The centre tab and recording: the mic.
  static IconData record(BuildContext context) =>
      context.isCupertino ? CupertinoIcons.mic : Icons.mic_none;

  /// Playback. Play mirrors in RTL (it points in the reading direction);
  /// pause is symmetric and doesn't.
  static IconData play(BuildContext context) => context.isCupertino
      ? _cupertinoPlay
      : const IconData(
          0xe4cb, // Icons.play_arrow (checked against the SDK in a test)
          fontFamily: 'MaterialIcons',
          matchTextDirection: true,
        );

  @visibleForTesting
  static IconData playForTest(BuildContext context) => play(context);

  @visibleForTesting
  static const IconData cupertinoPlayForTest = _cupertinoPlay;

  static const IconData _cupertinoPlay = IconData(
    0xf488, // CupertinoIcons.play_fill
    fontFamily: CupertinoIcons.iconFont,
    fontPackage: CupertinoIcons.iconFontPackage,
    matchTextDirection: true,
  );

  static IconData pause(BuildContext context) =>
      context.isCupertino ? CupertinoIcons.pause_fill : Icons.pause;

  /// The stories tab: a waveform.
  static IconData stories(BuildContext context) =>
      context.isCupertino ? CupertinoIcons.waveform : Icons.graphic_eq;

  /// The family tab.
  static IconData family(BuildContext context) =>
      context.isCupertino ? CupertinoIcons.person_2 : Icons.people_alt_outlined;

  static IconData search(BuildContext context) =>
      context.isCupertino ? CupertinoIcons.search : Icons.search;

  /// Invite a family member (person.badge.plus).
  static IconData invite(BuildContext context) => context.isCupertino
      ? CupertinoIcons.person_badge_plus
      : Icons.person_add_alt_outlined;

  static IconData close(BuildContext context) =>
      context.isCupertino ? CupertinoIcons.xmark : Icons.close;

  static IconData more(BuildContext context) =>
      context.isCupertino ? CupertinoIcons.ellipsis : Icons.more_horiz;

  /// Private content (visibility: only me).
  static IconData lock(BuildContext context) =>
      context.isCupertino ? CupertinoIcons.lock_fill : Icons.lock_outline;

  /// Empty state placeholder.
  static IconData empty(BuildContext context) =>
      context.isCupertino ? CupertinoIcons.tray : Icons.inbox_outlined;

  /// No connection.
  static IconData offline(BuildContext context) =>
      context.isCupertino ? CupertinoIcons.wifi_slash : Icons.wifi_off_outlined;

  /// Something went wrong.
  static IconData problem(BuildContext context) => context.isCupertino
      ? CupertinoIcons.exclamationmark_circle
      : Icons.error_outline;

  static IconData share(BuildContext context) =>
      context.isCupertino ? CupertinoIcons.share : Icons.share_outlined;

  // Family-tree zoom controls (spec 05 uses them; defined with the set).
  static IconData zoomIn(BuildContext context) =>
      context.isCupertino ? CupertinoIcons.zoom_in : Icons.zoom_in;

  static IconData zoomOut(BuildContext context) =>
      context.isCupertino ? CupertinoIcons.zoom_out : Icons.zoom_out;

  static IconData fitAll(BuildContext context) => context.isCupertino
      ? CupertinoIcons.arrow_up_left_arrow_down_right
      : Icons.fit_screen_outlined;

  static IconData centerMe(BuildContext context) => context.isCupertino
      ? CupertinoIcons.location_fill
      : Icons.my_location_outlined;

  static IconData bookmark(BuildContext context) =>
      context.isCupertino ? CupertinoIcons.bookmark : Icons.bookmark_border;

  static IconData checkCircle(BuildContext context) => context.isCupertino
      ? CupertinoIcons.checkmark_circle_fill
      : Icons.check_circle_outline;

  static IconData calendar(BuildContext context) => context.isCupertino
      ? CupertinoIcons.calendar
      : Icons.calendar_month_outlined;

  static IconData photo(BuildContext context) =>
      context.isCupertino ? CupertinoIcons.photo : Icons.photo_outlined;

  // Welcome slides: change them with the slides' content.
  static IconData onboardingWelcome(BuildContext context) => context.isCupertino
      ? CupertinoIcons.hand_raised
      : Icons.waving_hand_outlined;

  static IconData onboardingFeature(BuildContext context) => context.isCupertino
      ? CupertinoIcons.sparkles
      : Icons.auto_awesome_outlined;

  static IconData onboardingReady(BuildContext context) => context.isCupertino
      ? CupertinoIcons.checkmark_seal
      : Icons.rocket_launch_outlined;
}
