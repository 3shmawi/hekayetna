import 'package:family_stories/core/analytics/analytics.dart';
import 'package:family_stories/core/backend/backend.dart';
import 'package:family_stories/core/di/dependencies.dart';
import 'package:family_stories/core/monitoring/monitoring.dart';
import 'package:family_stories/core/privacy/consent.dart';
import 'package:family_stories/core/theme/app_fonts.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:flutter/widgets.dart';

/// Starts monitoring first, then initialises every core service and runs
/// the app. Anything that fails during start-up is reported.
/// Start-up markers, printed only with `--dart-define=BOOT_TRACE=true`
/// (the CI iOS diagnostic). Nothing is printed in normal builds.
const _bootTrace = bool.fromEnvironment('BOOT_TRACE');
void _mark(String step) {
  if (_bootTrace) debugPrint('[boot] $step');
}

Future<void> bootstrap(Widget Function() builder) async {
  WidgetsFlutterBinding.ensureInitialized();
  AppFonts.registerLicenses();
  _mark('start');
  await Monitoring.run(() async {
    _mark('monitoring running');
    await Backend.init();
    _mark('backend ready');
    await Consent.load();
    _mark('consent loaded');
    await Analytics.init();
    _mark('analytics ready');
    await Dependencies.init();
    _mark('dependencies ready');
    await AppUi.initialize();
    _mark('ui initialised');
    return AppUi.wrap(builder());
  });
  _mark('bootstrap returned');
}
