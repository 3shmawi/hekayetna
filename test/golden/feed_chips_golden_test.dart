@Tags(['golden'])
library;

import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/stories/data/models.dart';
import 'package:family_stories/features/stories/presentation/feed_filters.dart';
import 'package:family_stories/features/stories/presentation/story_feed_view.dart';
import 'package:family_stories/l10n/gen/app_localizations.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

/// Spec 03 AC-3: the filter chips never wrap, even with very long Arabic
/// names. Update with:
///
///   flutter test --update-goldens test/golden/feed_chips_golden_test.dart
const _longNames = [
  'الحاجة فاطمة عبد الرحمن محمد السيد أبو العينين',
  'عم عبد الفتاح إبراهيم الشرقاوي',
  'ماما',
];

Person _p(String id, String name) =>
    Person(id: id, spaceId: 's', fullName: name, createdBy: 'u');

void main() {
  setUp(() async {
    await loadAppFonts();
  });

  final persons = [
    for (var i = 0; i < _longNames.length; i++) _p('p$i', _longNames[i]),
  ];
  final stories = [
    for (var i = 0; i < _longNames.length; i++)
      Story(
        id: 's$i',
        spaceId: 's',
        title: 'حكاية $i',
        visibility: StoryVisibility.family,
        audioPath: 'a/$i',
        durationSeconds: 120,
        createdBy: 'u',
        createdAt: DateTime(2026),
        narratorIds: ['p$i'],
        topic: i == 0 ? 'ramadan_eid_traditions' : null,
        approxYear: 1950 + i * 10,
      ),
  ];

  for (final locale in const ['en', 'ar']) {
    for (final dark in const [false, true]) {
      final tag = '${locale}_${dark ? 'dark' : 'light'}';
      testWidgets('feed chips with long Arabic names · $tag', (t) async {
        t.view
          ..physicalSize = const Size(375, 812) * 2
          ..devicePixelRatio = 2;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          ProviderScope(
            child: ScreenUtilInit(
              designSize: AppDimens.designSize,
              builder: (context, _) => MaterialApp(
                debugShowCheckedModeBanner: false,
                locale: Locale(locale),
                theme: dark ? AppTheme.dark : AppTheme.light,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: StoryFeedView(
                    stories: AsyncData(stories),
                    options: FeedFilterOptions.from(stories, persons),
                    selection: const FeedSelection(),
                    narratorNames: {for (final p in persons) p.id: p.fullName},
                    onSelectionChanged: (_) {},
                    onRefresh: () async {},
                    onOpen: (_) {},
                    onPlay: (_) {},
                    onRecord: () {},
                    onAccount: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        // One line: every chip in the row is as tall as the "All" chip.
        final all = t.getSize(
          find.text(lookupAppLocalizations(Locale(locale)).feedFilterAll),
        );
        // The row is lazy: only chips near the viewport are built.
        final built = _longNames.where(
          (n) => find.text(n).evaluate().isNotEmpty,
        );
        expect(built, isNotEmpty);
        for (final name in built) {
          final box = t.getSize(find.text(name).first);
          expect(box.height, lessThanOrEqualTo(all.height * 1.5), reason: name);
        }
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/feed_chips_long_ar_$tag.png'),
        );
      });
    }
  }
}
