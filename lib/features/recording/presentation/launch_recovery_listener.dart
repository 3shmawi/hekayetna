import 'dart:async';

import 'package:family_stories/app/app_providers.dart';
import 'package:family_stories/core/privacy/consent.dart';
import 'package:family_stories/core/privacy/consent_sheet.dart';
import 'package:family_stories/core/router/app_routes.dart';
import 'package:family_stories/features/recording/data/recorder_service.dart';
import 'package:family_stories/features/recording/presentation/continue_recording_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Spec 02, "once on app launch": if the app was closed mid-recording, open
/// the Continue a recording screen over wherever the user landed.
///
/// Once per launch, never before the user is past onboarding and sign-in
/// (it waits for the home route), never while the privacy sheet is still
/// to be answered, and never while a take is live.
class LaunchRecoveryListener extends ConsumerStatefulWidget {
  const LaunchRecoveryListener({
    required this.router,
    required this.child,
    super.key,
  });

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<LaunchRecoveryListener> createState() =>
      _LaunchRecoveryListenerState();
}

class _LaunchRecoveryListenerState
    extends ConsumerState<LaunchRecoveryListener> {
  bool _done = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_maybeShow);
    Consent.analytics.addListener(_maybeShow);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_maybeShow);
    Consent.analytics.removeListener(_maybeShow);
    super.dispose();
  }

  void _maybeShow() {
    if (_done || _checking || !mounted) return;
    final path = widget.router.routerDelegate.currentConfiguration.uri.path;
    if (path != AppRoutes.home) return;
    if (ConsentListener.isNeeded &&
        Consent.analytics.value == ConsentChoice.unknown) {
      return;
    }
    _checking = true;
    unawaited(_check());
  }

  Future<void> _check() async {
    try {
      final status = ref.read(recorderServiceProvider).state.status;
      if (status != RecorderStatus.idle) {
        _done = true;
        return;
      }
      final drafts = await interruptedDrafts(ref);
      _done = true;
      if (drafts.isEmpty || !mounted) return;
      unawaited(widget.router.push('/record/continue'));
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
