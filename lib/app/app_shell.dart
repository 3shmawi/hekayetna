import 'package:family_stories/core/privacy/consent_sheet.dart';
import 'package:family_stories/core/router/app_router.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/core/update/app_update_listener.dart';
import 'package:family_stories/core/widgets/offline_banner.dart';
import 'package:family_stories/features/settings/data/app_settings.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The MaterialApp, configured once: screen scaling, themes, localization
/// (Arabic → RTL automatically), routing and the update gate.
class AppShell extends StatelessWidget {
  const AppShell({required this.settings, super.key});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: AppDimens.designSize,
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, _) => MaterialApp.router(
        onGenerateTitle: (context) => context.l10n.appTitle,
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: settings.themeMode,
        locale: settings.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => AppUpdateListener(
          child: ConsentListener(
            child: OfflineBanner(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
