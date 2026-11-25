@Tags(['golden'])
library;

import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/features/family/domain/family_graph.dart';
import 'package:family_stories/features/family/presentation/family_tree_canvas.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/family/domain/family_fixtures.dart';

/// The tree canvas at 100% and 60% zoom, light/dark x en/ar (spec 05,
/// AC-4). These use the box test font, so they check structure only; the
/// real-font renders live in test/screenshot/shots.
/// Update with `flutter test --update-goldens test/golden/family_tree_golden_test.dart`
/// and look at every PNG.
FamilyGraph _graph() {
  final fam = bigFamily();
  return FamilyGraph.build(
    persons: fam.persons,
    relationships: fam.rels,
    meId: 'me',
    storiesByNarrator: {
      'sitto': [600, 300, 120],
      'mama': [60],
    },
  );
}

void main() {
  for (final zoom in const [1.0, 0.6]) {
    for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
      for (final locale in const ['en', 'ar']) {
        final variant = 'tree_${(zoom * 100).round()}_${mode.name}_$locale';
        testWidgets(variant, (tester) async {
          tester.view
            ..physicalSize = const Size(375, 812) * 2
            ..devicePixelRatio = 2;
          addTearDown(tester.view.reset);
          final controller = FamilyTreeController();
          await tester.pumpWidget(
            ScreenUtilInit(
              designSize: AppDimens.designSize,
              builder: (context, _) => MaterialApp(
                debugShowCheckedModeBanner: false,
                locale: Locale(locale),
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                themeMode: mode,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: SafeArea(
                    child: FamilyTreeCanvas(
                      graph: _graph(),
                      controller: controller,
                      onTapPerson: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump();
          if (zoom != 1.0) {
            controller.zoomBy(zoom);
            await tester.pump();
          }
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/family/$variant.png'),
          );
        });
      }
    }
  }
}
