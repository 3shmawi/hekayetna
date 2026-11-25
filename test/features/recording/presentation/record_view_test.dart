import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/features/recording/presentation/record_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

RecordView _view({
  RecordButtonState state = RecordButtonState.idle,
  bool canFinish = false,
  String? prompt = 'What is your earliest memory?',
  List<double> levels = const [],
  VoidCallback? onDone,
  VoidCallback? onToggle,
  VoidCallback? onNarrator,
  VoidCallback? onTopic,
  VoidCallback? onClose,
}) => RecordView(
  buttonState: state,
  elapsed: const Duration(minutes: 1, seconds: 5),
  levels: levels,
  narratorName: 'Sitto',
  draftSaved: true,
  canFinish: canFinish,
  promptText: prompt,
  onDifferentQuestion: () {},
  onClose: onClose ?? () {},
  onToggle: onToggle ?? () {},
  onPickNarrator: onNarrator ?? () {},
  onPickTopic: onTopic ?? () {},
  onDone: onDone ?? () {},
);

void main() {
  testWidgets('AC-3: Done is disabled until something is recorded', (
    tester,
  ) async {
    var done = 0;
    await tester.pumpApp(_view(onDone: () => done++));
    await tester.tap(find.text('Done'));
    expect(done, 0);

    await tester.pumpApp(_view(canFinish: true, onDone: () => done++));
    await tester.tap(find.text('Done'));
    expect(done, 1);
  });

  testWidgets('shows the draft line, narrator, timer and status', (
    tester,
  ) async {
    await tester.pumpApp(_view(state: RecordButtonState.paused));
    expect(find.text('Draft saved on this phone'), findsOneWidget);
    expect(find.text('Speaking: Sitto'), findsOneWidget);
    expect(find.text('01:05'), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);
  });

  testWidgets('the prompt card hides when prompts are off', (tester) async {
    await tester.pumpApp(_view());
    expect(find.text('What is your earliest memory?'), findsOneWidget);
    await tester.pumpApp(_view(prompt: null));
    expect(find.text('What is your earliest memory?'), findsNothing);
    expect(find.text('Ask her / him'), findsNothing);
  });

  testWidgets('narrator chip, topic, record and close call back', (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpApp(
      _view(
        onNarrator: () => calls.add('narrator'),
        onTopic: () => calls.add('topic'),
        onToggle: () => calls.add('toggle'),
        onClose: () => calls.add('close'),
      ),
    );
    await tester.tap(find.text('Speaking: Sitto'));
    await tester.tap(find.text('Topic'));
    await tester.tap(find.byType(RecordButton));
    await tester.tap(find.byTooltip('Close, the draft is kept'));
    expect(calls, ['narrator', 'topic', 'toggle', 'close']);
  });

  testWidgets(
    'the level meter always has 20 bars and reduce motion adds none',
    (tester) async {
      await tester.pumpApp(
        _view(state: RecordButtonState.recording, levels: List.filled(35, 0.5)),
      );
      final bars = find.descendant(
        of: find.bySemanticsLabel('Sound level'),
        matching: find.byType(Container),
      );
      expect(bars, findsNWidgets(kLevelBars));
      expect(find.byType(AnimatedContainer), findsNothing);
    },
  );

  testWidgets('a pause note explains why the take paused', (tester) async {
    await tester.pumpApp(
      RecordView(
        buttonState: RecordButtonState.paused,
        elapsed: Duration.zero,
        levels: const [],
        narratorName: null,
        draftSaved: false,
        canFinish: true,
        note: 'Paused because a call came in. Tap to continue.',
        onClose: () {},
        onToggle: () {},
        onPickNarrator: () {},
        onPickTopic: () {},
        onDone: () {},
      ),
    );
    expect(find.textContaining('a call came in'), findsOneWidget);
    expect(find.text('Draft saved on this phone'), findsNothing);
    expect(find.text('Speaking: Add a person'), findsOneWidget);
  });

  testWidgets('accessible in light mode', (tester) async {
    await tester.pumpApp(_view(canFinish: true));
    await tester.expectAccessible();
  });
}
