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
Future<void> bootstrap(Widget Function() builder) async {
  WidgetsFlutterBinding.ensureInitialized();
  AppFonts.registerLicenses();
  await Monitoring.run(() async {
    await Backend.init();
    await Consent.load();
    await Analytics.init();
    await Dependencies.init();
    await AppUi.initialize();
    return AppUi.wrap(builder());
  });
}
