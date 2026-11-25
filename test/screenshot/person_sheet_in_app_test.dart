@Tags(['golden'])
library;

import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/features/family/domain/family_graph.dart';
import 'package:family_stories/features/family/presentation/family_tree_page.dart';
import 'package:family_stories/features/family/presentation/family_tree_providers.dart';
import 'package:family_stories/features/family/presentation/person_sheet.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/presentation/story_providers.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/family/domain/family_fixtures.dart';
import 'real_font_screens_test.dart' show loadRealFonts;

/// The person sheet opened with showPersonSheet over the real tree page
/// (so the handle, the rounded top, the dimmed page behind and scrolling
/// are the app's own), at normal and 160% text. Real fonts.
/// Output: test/screenshot/shots/person_sheet_app_*.png.
FamilyGraph _graph() {
  final fam = bigFamily();
  return FamilyGraph.build(
    persons: fam.persons,
    relationships: fam.rels,
    meId: 'me',
    storiesByNarrator: {
      'sitto': [600, 300, 120],
    },
  );
}

Story _story(String id, String topic, String title) => Story(
  id: id,
  spaceId: 's',
  title: title,
  visibility: StoryVisibility.family,
  audioPath: 'p/$id.wav',
  durationSeconds: 300,
  createdBy: 'u',
  createdAt: DateTime(2026),
  narratorIds: const ['sitto'],
  topic: topic,
);

class _Feed extends StoryFeedNotifier {
  _Feed(super.filter);
  @override
  Future<List<Story>> build() async => [
    _story('a', 'childhood_first_home', 'The house by the canal'),
    _story('b', 'how_parents_met', 'How I met your grandfather'),
    _story('c', 'funny_memories', 'The goat at the wedding'),
    _story('d', 'funny_memories', 'The lost shoe'),
  ];
}

void main() {
  setUp(loadRealFonts);
  for (final locale in const ['en', 'ar']) {
    for (final scale in const [1.0, 1.6]) {
      final name = 'person_sheet_app_${(scale * 100).round()}_$locale';
      testWidgets(name, (tester) async {
        tester.view
          ..physicalSize = const Size(375, 812) * 2
          ..devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              familyGraphProvider.overrideWith((ref, _) async => _graph()),
              familyTreeGraphEnabledProvider.overrideWith((ref) async => true),
              storyFeedProvider.overrideWith2(_Feed.new),
            ],
            child: ScreenUtilInit(
              designSize: AppDimens.designSize,
              builder: (context, _) => MaterialApp(
                debugShowCheckedModeBanner: false,
                locale: Locale(locale),
                theme: AppTheme.light,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: SafeArea(
                    child: FamilyTreePage(
                      spaceId: 's',
                      spaceName: 'Ashmawy family',
                      onOpenPerson: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final ctx = tester.element(find.byType(FamilyTreePage));
        // ignore: unawaited_futures, the sheet future completes only on close.
        showPersonSheet(ctx, graph: _graph(), personId: 'sitto');
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('shots/$name.png'),
        );
        if (scale > 1) {
          await tester.drag(find.byType(PersonSheet), const Offset(0, -2000));
          await tester.pumpAndSettle();
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('shots/${name}_end.png'),
          );
        }
      });
    }
  }
}
