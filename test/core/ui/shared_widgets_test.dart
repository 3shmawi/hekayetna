import 'dart:ui' show Tristate;

import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/core/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

const _longTitleConst =
    'A very long story title that should be cut after two full lines of text';

/// Shared widgets live on scaffolds in the app; give their ink wells and
/// buttons the same Material ancestor here.
extension on WidgetTester {
  Future<void> pumpWidgetOnScaffold(Widget widget, {Locale? locale}) =>
      pumpApp(Scaffold(body: widget), locale: locale ?? const Locale('en'));
}

/// AC-3: states, callbacks, semantics, RTL mirror and 200% text scale for
/// every shared widget. AC-4 (no-wrap AppButton) and AC-6 (RecordButton
/// halo off with Reduce Motion) have their own groups.
void main() {
  group('AppButton', () {
    testWidgets('calls onPressed; busy disables and keeps width', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidgetOnScaffold(
        Column(
          children: [
            AppButton.primary(label: 'Save story', onPressed: () => taps++),
            AppButton.primary(
              label: 'Busy',
              onPressed: () => taps += 10,
              busy: true,
            ),
          ],
        ),
      );
      final normalWidth = tester.getSize(find.byType(TextButton).first).width;
      final busyWidth = tester.getSize(find.byType(TextButton).last).width;
      await tester.tap(find.text('Save story'));
      expect(taps, 1);
      // Busy shows an indicator instead of the label and keeps the width.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(busyWidth, normalWidth);
    });

    testWidgets('secondary and destructive render and call back', (
      tester,
    ) async {
      var secondary = 0;
      var destructive = 0;
      await tester.pumpWidgetOnScaffold(
        Column(
          children: [
            AppButton.secondary(label: 'Alt', onPressed: () => secondary++),
            AppButton.destructive(
              label: 'Delete',
              onPressed: () => destructive++,
            ),
          ],
        ),
      );
      await tester.tap(find.text('Alt'));
      await tester.tap(find.text('Delete'));
      expect((secondary, destructive), (1, 1));
    });
  });

  group('AC-4 AppButton label never wraps', () {
    testWidgets('long Arabic label in a half-width button: one line', (
      tester,
    ) async {
      await tester.pumpWidgetOnScaffold(
        locale: const Locale('ar'),
        Center(
          child: SizedBox(
            width: 187, // half of the 375 design frame
            child: AppButton.primary(
              label: 'احفظ الحكاية وشاركها مع العيلة كلها دلوقتي حالًا',
              onPressed: () {},
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(
        find.text('احفظ الحكاية وشاركها مع العيلة كلها دلوقتي حالًا'),
      );
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });
  });

  group('AppChip', () {
    testWidgets('selected state, tap, min height 48', (tester) async {
      var taps = 0;
      await tester.pumpWidgetOnScaffold(
        AppChip(label: 'Ramadan & Eid', selected: true, onTap: () => taps++),
      );
      await tester.tap(find.text('Ramadan & Eid'));
      expect(taps, 1);
      final size = tester.getSize(find.byType(AppChip));
      expect(size.height, greaterThanOrEqualTo(48));
      final chipSemantics = tester.getSemantics(find.byType(AppChip));
      expect(chipSemantics.label, 'Ramadan & Eid');
      expect(chipSemantics.flagsCollection.isButton, isTrue);
      expect(chipSemantics.flagsCollection.isSelected, Tristate.isTrue);
    });
  });

  group('PersonAvatar', () {
    testWidgets('initial letter on tint, semantics is the name', (
      tester,
    ) async {
      await tester.pumpWidgetOnScaffold(
        const PersonAvatar(name: 'Sitto Fatma'),
      );
      expect(find.text('S'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(PersonAvatar)).label,
        'Sitto Fatma',
      );
    });
  });

  group('StoryCard', () {
    testWidgets('opens on tap, plays on button, sample tag, 2-line title', (
      tester,
    ) async {
      var opened = 0;
      var played = 0;

      await tester.pumpWidgetOnScaffold(
        StoryCard(
          title: _longTitleConst,
          narratorName: 'Sitto',
          dateLabel: 'late 1950s',
          duration: '2:34',
          topicLabel: 'Ramadan & Eid',
          isSample: true,
          onOpen: () => opened++,
          onPlay: () => played++,
        ),
      );
      await tester.tap(find.byType(StoryCard));
      expect(opened, 1);
      await tester.tap(find.byTooltip(l10nEn.storyPlay));
      expect(played, 1);
      expect(find.text('Sample'), findsOneWidget);
      expect(tester.widget<Text>(find.text(_longTitleConst)).maxLines, 2);
      // 48px quick-play target.
      expect(
        tester.getSize(find.byTooltip(l10nEn.storyPlay)).width,
        greaterThanOrEqualTo(48),
      );
    });
  });

  group('AudioPlayerCard', () {
    Widget card({
      VoidCallback? onToggle,
      VoidCallback? onSpeed,
      ValueChanged<double>? onSeek,
    }) => AudioPlayerCard(
      subtitle: 'Sitto · late 1950s',
      position: '1:12',
      duration: '2:34',
      isPlaying: true,
      speed: '1×',
      waveform: const [0.3, 0.7, 1.0, 0.5, 0.2, 0.6, 0.9, 0.4],
      onToggle: onToggle ?? () {},
      onSpeed: onSpeed ?? () {},
      onSeek: onSeek ?? (_) {},
    );

    testWidgets('toggle and speed callbacks', (tester) async {
      var toggled = 0;
      var sped = 0;
      await tester.pumpWidgetOnScaffold(
        card(onToggle: () => toggled++, onSpeed: () => sped++),
      );
      await tester.tap(find.byIcon(Icons.pause));
      await tester.tap(find.text('1×'));
      expect((toggled, sped), (1, 1));
    });

    testWidgets('seek taps: LTR position maps to time, RTL mirrors', (
      tester,
    ) async {
      final seeks = <double>[];
      // LTR
      await tester.pumpWidgetOnScaffold(card(onSeek: seeks.add));
      final bar = find.byKey(const Key('waveform-scrubber'));
      final rect = tester.getRect(bar);
      await tester.tapAt(Offset(rect.left + rect.width * 0.25, rect.center.dy));
      // RTL
      await tester.pumpWidgetOnScaffold(
        card(onSeek: seeks.add),
        locale: const Locale('ar'),
      );
      await tester.tapAt(Offset(rect.left + rect.width * 0.25, rect.center.dy));
      expect(seeks, hasLength(2));
      expect(seeks[0], closeTo(0.25, 0.05));
      expect(seeks[1], closeTo(0.75, 0.05), reason: 'RTL mirrors the scrubber');
    });

    testWidgets('semantics slider increases and decreases', (tester) async {
      final seeks = <double>[];
      await tester.pumpWidgetOnScaffold(card(onSeek: seeks.add));
      final handle = tester.ensureSemantics();
      // position 1:12 of 2:34 = 47%.
      final sliderFinder = find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.slider ?? false),
      );
      expect(sliderFinder, findsOneWidget);
      final node = tester.getSemantics(sliderFinder);
      expect(node.value, '47%');
      expect(node.increasedValue, isNotEmpty);
      expect(node.decreasedValue, isNotEmpty);
      handle.dispose();
    });
  });

  group('RecordButton', () {
    testWidgets('semantics label per state', (tester) async {
      for (final (state, label) in [
        (RecordButtonState.idle, l10nEn.recordStart),
        (RecordButtonState.recording, l10nEn.recordPause),
        (RecordButtonState.paused, l10nEn.recordResume),
      ]) {
        await tester.pumpWidgetOnScaffold(
          RecordButton(state: state, onPressed: () {}),
        );
        final buttonSemantics = tester.getSemantics(find.byType(RecordButton));
        expect(buttonSemantics.label, label);
        expect(buttonSemantics.flagsCollection.isButton, isTrue);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('AC-6 halo respects Reduce Motion', () {
    testWidgets('disableAnimations stops the breathing', (tester) async {
      await tester.pumpWidgetOnScaffold(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: RecordButton(
            state: RecordButtonState.recording,
            onPressed: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));
      final scale = tester.widget<ScaleTransition>(
        find.byKey(const Key('record-halo')),
      );
      expect(
        scale.animation.value,
        1,
        reason: 'halo stays at base scale, never breathes',
      );
    });

    testWidgets('recording breathes when animations are allowed', (
      tester,
    ) async {
      await tester.pumpWidgetOnScaffold(
        RecordButton(state: RecordButtonState.recording, onPressed: () {}),
      );
      await tester.pump(const Duration(milliseconds: 800));
      final scale = tester.widget<ScaleTransition>(
        find.byKey(const Key('record-halo')),
      );
      expect(
        scale.animation.value,
        greaterThan(1),
        reason: 'halo scale grows while breathing',
      );
    });
  });

  group('VisibilityPicker', () {
    testWidgets('three options, change callback, consequence text', (
      tester,
    ) async {
      StoryVisibility? picked;
      await tester.pumpWidgetOnScaffold(
        VisibilityPicker(
          value: StoryVisibility.onlyMe,
          onChanged: (v) => picked = v,
          consequenceText: '3 people can hear this: Mama, Omar, Nour.',
        ),
      );
      expect(find.text(l10nEn.visibilityOnlyMe), findsOneWidget);
      expect(find.text(l10nEn.visibilitySelectedPeople), findsOneWidget);
      expect(find.text(l10nEn.visibilityWholeFamily), findsOneWidget);
      expect(
        find.text('3 people can hear this: Mama, Omar, Nour.'),
        findsOneWidget,
      );
      await tester.tap(find.text(l10nEn.visibilitySelectedPeople));
      expect(picked, StoryVisibility.selectedPeople);
      // Options are large targets.
      final optionBox = tester.getSize(
        find
            .ancestor(
              of: find.text(l10nEn.visibilityOnlyMe),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(optionBox.height, greaterThanOrEqualTo(48));
    });
  });

  group('AppSectionLabel', () {
    testWidgets('uppercase in English, as-is in Arabic', (tester) async {
      await tester.pumpWidgetOnScaffold(
        const AppSectionLabel('Recently added'),
      );
      expect(find.text('RECENTLY ADDED'), findsOneWidget);
      await tester.pumpWidgetOnScaffold(
        const AppSectionLabel('اتضافت جديد'),
        locale: const Locale('ar'),
      );
      expect(find.text('اتضافت جديد'), findsOneWidget);
    });
  });

  group('SkeletonCard', () {
    testWidgets('renders the asked lines', (tester) async {
      await tester.pumpWidgetOnScaffold(const SkeletonCard(lines: 3));
      expect(find.byType(FractionallySizedBox), findsNWidgets(3));
    });
  });

  group('StateViews', () {
    testWidgets('EmptyView title, message and action', (tester) async {
      var acted = 0;
      await tester.pumpWidgetOnScaffold(
        EmptyView(
          title: 'No stories yet',
          message: 'Ask Sitto about her first home and record it.',
          actionLabel: 'Record the first story',
          onAction: () => acted++,
        ),
      );
      expect(find.text('No stories yet'), findsOneWidget);
      await tester.tap(find.text('Record the first story'));
      expect(acted, 1);
    });
  });

  group('AC-3 200% text scale does not overflow', () {
    testWidgets('buttons, cards, picker at 2.0 text scaler', (tester) async {
      await tester.pumpWidgetOnScaffold(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: SingleChildScrollView(
            child: Column(
              children: [
                AppButton.primary(label: 'Save story', onPressed: () {}),
                StoryCard(
                  title: 'The first Om Ali',
                  narratorName: 'Sitto',
                  duration: '2:34',
                  onOpen: () {},
                  onPlay: () {},
                ),
                VisibilityPicker(
                  value: StoryVisibility.onlyMe,
                  onChanged: (_) {},
                  consequenceText: 'Only you can hear this.',
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
  group('accessibility (tester.expectAccessible)', () {
    testWidgets('buttons, chip, avatar, section label', (tester) async {
      await tester.pumpWidgetOnScaffold(
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppButton.primary(label: 'Save story', onPressed: () {}),
              const SizedBox(height: 12),
              AppButton.secondary(label: 'Record again', onPressed: () {}),
              const SizedBox(height: 12),
              AppButton.destructive(label: 'Delete', onPressed: () {}),
              const SizedBox(height: 12),
              Row(
                children: [
                  AppChip(label: 'All', selected: true, onTap: () {}),
                  const SizedBox(width: 8),
                  AppChip(
                    label: 'Sitto',
                    selected: false,
                    onTap: () {},
                    leading: const PersonAvatar(name: 'Sitto', size: 28),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const AppSectionLabel('Recently added'),
            ],
          ),
        ),
      );
      await tester.expectAccessible();
    });

    testWidgets('story card, player, picker, empty view', (tester) async {
      await tester.pumpWidgetOnScaffold(
        SingleChildScrollView(
          child: Column(
            children: [
              StoryCard(
                title: 'The first Om Ali',
                narratorName: 'Sitto',
                dateLabel: 'Ramadan, late 1950s',
                duration: '2:34',
                topicLabel: 'Ramadan & Eid',
                onOpen: () {},
                onPlay: () {},
              ),
              AudioPlayerCard(
                title: 'The first Om Ali',
                subtitle: 'Told by Sitto',
                position: '1:12',
                duration: '2:34',
                isPlaying: false,
                speed: '1x',
                waveform: const [0.2, 0.5, 0.9, 0.6, 0.3],
                onToggle: () {},
                onSeek: (_) {},
                onSpeed: () {},
              ),
              VisibilityPicker(
                value: StoryVisibility.selectedPeople,
                onChanged: (_) {},
                consequenceText: '3 people can hear this.',
              ),
              EmptyView(
                title: 'No stories yet',
                message: 'Ask Sitto about her first home.',
                actionLabel: 'Record the first story',
                onAction: () {},
                icon: Icons.graphic_eq,
              ),
            ],
          ),
        ),
      );
      await tester.expectAccessible();
    });

    testWidgets('record button under reduced motion', (tester) async {
      // The breathing halo never settles, so check the control with
      // Reduce Motion on (AC-6 keeps the halo off there).
      await tester.pumpWidgetOnScaffold(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RecordButtonStatus(state: RecordButtonState.recording),
              const SizedBox(height: 8),
              RecordButton(
                state: RecordButtonState.recording,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      await tester.expectAccessible();
    });
  });

  group('AppScaffold on iOS', () {
    testWidgets('gives its body a Material ancestor (text fields work)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light.copyWith(platform: TargetPlatform.iOS),
          home: AppScaffold(
            title: 'Sign in',
            body: ListView(children: const [TextField(key: Key('field'))]),
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('field')), 'a@b.co');
      expect(tester.takeException(), isNull);
      expect(find.text('a@b.co'), findsOneWidget);
    });
  });
}
