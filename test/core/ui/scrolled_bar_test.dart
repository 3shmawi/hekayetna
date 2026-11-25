import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/core/theme/hekayetna_colors.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// The top bar must stay dark (readable title and back button) when the
/// content scrolls under it, on both platforms (user report, Save story).
void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('dark top bar stays dark after scrolling on $platform', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1125, 2436)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        AppUi.testWrap(
          ScreenUtilInit(
            designSize: AppDimens.designSize,
            builder: (context, _) => MaterialApp(
              theme: AppTheme.dark.copyWith(platform: platform),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Navigator(
                pages: [
                  MaterialPage<void>(child: const SizedBox()),
                  MaterialPage<void>(
                    child: AppScaffold(
                      title: 'Save story',
                      body: ListView(
                        children: [
                          for (var i = 0; i < 40; i++)
                            SizedBox(height: 60, child: Text('row $i')),
                        ],
                      ),
                    ),
                  ),
                ],
                onDidRemovePage: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      final sand = HekayetnaColors.dark.sand;
      if (platform == TargetPlatform.iOS) {
        final bar = tester.widget<CupertinoNavigationBar>(
          find.byType(CupertinoNavigationBar),
        );
        expect(bar.backgroundColor, sand);
        expect(bar.backgroundColor!.a, 1);
      } else {
        final bar = tester.widget<AppBar>(find.byType(AppBar));
        expect(bar.backgroundColor, isNull); // from the theme
        final theme = Theme.of(tester.element(find.byType(AppBar)));
        expect(theme.appBarTheme.backgroundColor, sand);
        expect(theme.appBarTheme.scrolledUnderElevation, 0);
        expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
      }
    });
  }
}
