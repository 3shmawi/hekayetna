import 'package:family_stories/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';

export 'package:family_stories/l10n/gen/app_localizations.dart';

/// `context.l10n.someKey` — every user-facing string comes from the ARB files
/// in lib/l10n (app_en.arb is the template, app_ar.arb the translation).
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
