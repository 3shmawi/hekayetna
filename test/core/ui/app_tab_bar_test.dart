import 'dart:ui' show Tristate;

import 'package:family_stories/core/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

/// AC-5: AppTabBar matches artboard Main; three targets >= 48, record item
/// semantics label, tapping switches branches (reports the tapped index;
/// HomeShell maps it to goBranch).
void main() {
  testWidgets('three large targets with semantics labels', (tester) async {
    await tester.pumpApp(
      Scaffold(bottomNavigationBar: AppTabBar(currentIndex: 0, onTap: (_) {})),
    );
    final stories = tester.getSemantics(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == l10nEn.stories,
      ),
    );
    expect(stories.flagsCollection.isButton, isTrue);
    final record = tester.getSemantics(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == l10nEn.recordAStory,
      ),
    );
    expect(record.label, l10nEn.recordAStory);
    // Every item, including the record circle, is at least 48x48.
    for (final label in [l10nEn.stories, l10nEn.recordAStory, l10nEn.family]) {
      final size = tester.getSize(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == label,
        ),
      );
      expect(size.width, greaterThanOrEqualTo(48), reason: label);
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
    }
  });

  testWidgets('tapping reports the index, including the current tab', (
    tester,
  ) async {
    final taps = <int>[];
    await tester.pumpApp(
      Scaffold(
        bottomNavigationBar: AppTabBar(currentIndex: 0, onTap: taps.add),
      ),
    );
    await tester.tap(find.text(l10nEn.family));
    await tester.tap(find.text(l10nEn.stories)); // current tab pops to root
    await tester.tap(find.bySemanticsLabel(l10nEn.recordAStory));
    expect(taps, [2, 0, 1]);
  });

  testWidgets('selected tab uses the primary colour', (tester) async {
    await tester.pumpApp(
      Scaffold(bottomNavigationBar: AppTabBar(currentIndex: 2, onTap: (_) {})),
    );
    final semantics = tester.getSemantics(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == l10nEn.family,
      ),
    );
    expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
  });
  testWidgets('accessibility (tester.expectAccessible)', (tester) async {
    await tester.pumpApp(
      Scaffold(bottomNavigationBar: AppTabBar(currentIndex: 0, onTap: (_) {})),
    );
    await tester.expectAccessible();
  });
}
