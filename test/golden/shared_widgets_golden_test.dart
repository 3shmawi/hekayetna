@Tags(['golden'])
library;

import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/core/widgets/state_views.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

/// Every shared widget in light and dark, LTR (English) and RTL (Arabic),
/// with the app's real fonts. Update with:
///
///   flutter test --update-goldens test/golden/shared_widgets_golden_test.dart
///
/// and look at every PNG before committing.
final Map<String, Widget Function()> widgets = {
  'buttons': () => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppButton.primary(label: 'Save story', onPressed: () {}),
      const SizedBox(height: 12),
      AppButton.secondary(label: 'Record again', onPressed: () {}),
      const SizedBox(height: 12),
      AppButton.destructive(label: 'Delete', onPressed: () {}),
      const SizedBox(height: 12),
      AppButton.record(label: 'Start recording', onPressed: () {}),
      const SizedBox(height: 12),
      AppButton.primary(label: 'Busy', onPressed: () {}, busy: true),
    ],
  ),
  // AC-4: a long Arabic label in a half-width button stays on one line.
  'button_no_wrap': () => FractionallySizedBox(
    widthFactor: 0.5,
    child: AppButton.primary(
      label: 'احفظ الحكاية وشاركها مع العيلة كلها دلوقتي حالًا',
      onPressed: () {},
    ),
  ),
  'chips': () => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      AppChip(label: 'All', selected: true, onTap: () {}),
      AppChip(label: 'Ramadan & Eid', selected: false, onTap: () {}),
      AppChip(
        label: 'Sitto',
        selected: false,
        onTap: () {},
        leading: const PersonAvatar(name: 'Sitto', size: 28),
      ),
    ],
  ),
  'story_card': () => StoryCard(
    title: 'The first Om Ali',
    narratorName: 'Sitto',
    dateLabel: 'Ramadan, late 1950s',
    duration: '2:34',
    topicLabel: 'Ramadan & Eid',
    onOpen: () {},
    onPlay: () {},
  ),
  'story_card_sample': () => StoryCard(
    title: 'Moving to Shubra in 63',
    narratorName: 'Giddu',
    dateLabel: 'Early 1960s',
    duration: '4:08',
    topicLabel: 'Childhood & first home',
    isSample: true,
    onOpen: () {},
    onPlay: () {},
  ),
  'audio_player': () => AudioPlayerCard(
    title: 'The first Om Ali',
    subtitle: 'Told by Sitto · Ramadan, late 1950s',
    position: '1:12',
    duration: '2:34',
    isPlaying: true,
    speed: '1×',
    waveform: const [
      0.2,
      0.5,
      0.9,
      0.6,
      0.3,
      0.7,
      1.0,
      0.8,
      0.4,
      0.6,
      0.9,
      0.5,
      0.3,
      0.2,
    ],
    onToggle: () {},
    onSeek: (_) {},
    onSpeed: () {},
  ),
  'record_button': () => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const RecordButtonStatus(state: RecordButtonState.recording),
      const SizedBox(height: 8),
      RecordButton(state: RecordButtonState.recording, onPressed: () {}),
    ],
  ),
  'record_button_paused': () => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const RecordButtonStatus(state: RecordButtonState.paused),
      const SizedBox(height: 8),
      RecordButton(state: RecordButtonState.paused, onPressed: () {}),
    ],
  ),
  'visibility_picker': () => VisibilityPicker(
    value: StoryVisibility.selectedPeople,
    onChanged: (_) {},
    consequenceText: '3 people can hear this: Mama, Omar, Nour.',
  ),
  'section_label': () => const AppSectionLabel('Recently added'),
  'tab_bar': () => Align(
    alignment: Alignment.bottomCenter,
    child: AppTabBar(currentIndex: 0, onTap: (_) {}),
  ),
  'skeleton_card': () => const SkeletonCard(),
  'empty_view': () => SizedBox(
    height: 400,
    child: EmptyView(
      title: 'No stories yet',
      message: 'Ask Sitto about her first home and record it.',
      actionLabel: 'Record the first story',
      onAction: () {},
      icon: Icons.graphic_eq,
    ),
  ),
};

void main() {
  setUp(() async {
    await loadAppFonts();
  });

  for (final MapEntry(key: name, value: build) in widgets.entries) {
    for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
      for (final locale in const ['en', 'ar']) {
        final variant = '${name}_${mode.name}_$locale';
        testWidgets(variant, (tester) async {
          tester.view
            ..physicalSize = const Size(375, 812) * 2
            ..devicePixelRatio = 2;
          addTearDown(tester.view.reset);
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
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: build(),
                    ),
                  ),
                ),
              ),
            ),
          );
          // Fixed pumps: busy spinners and the breathing halo never settle.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 800));
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/widgets/$variant.png'),
          );
        });
      }
    }
  }
}
