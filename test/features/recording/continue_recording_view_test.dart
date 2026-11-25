import 'package:family_stories/features/recording/presentation/continue_recording_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

const _a = ResumeItem(
  id: 'a',
  title: 'Ramadan in the old house',
  narratorName: 'Sitto Fatma',
  stoppedAtLabel: 'yesterday at 8:40 pm',
  segmentMs: [240000, 225000],
);
const _b = ResumeItem(
  id: 'b',
  title: 'Unfinished recording',
  narratorName: null,
  stoppedAtLabel: 'today at 9:05 am',
  segmentMs: [61000],
);

Widget _view(List<ResumeItem> items, {List<String>? log, String? playing}) =>
    ContinueRecordingView(
      items: items,
      playingId: playing,
      onPlayToggle: (i) => log?.add('play ${i.id}'),
      onContinue: (i) => log?.add('continue ${i.id}'),
      onSave: (i) => log?.add('save ${i.id}'),
      onDelete: (i) => log?.add('delete ${i.id}'),
      onClose: () => log?.add('close'),
    );

Future<void> _tall(WidgetTester t) async {
  t.view
    ..physicalSize = const Size(1000, 3000)
    ..devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pump();
}

void main() {
  test('kept time is the sum of the segments', () {
    expect(_a.keptMs, 465000);
    expect(formatKept(465000), '7:45');
    expect(formatKept(61000), '1:01');
    expect(formatKept(3725000), '1:02:05');
  });

  testWidgets('shows the title, when it stopped, kept time and parts', (
    t,
  ) async {
    await t.pumpApp(_view([_a]));
    await _tall(t);
    expect(
      find.text('Your recording with Sitto Fatma is safe'),
      findsOneWidget,
    );
    expect(find.textContaining('yesterday at 8:40 pm'), findsOneWidget);
    expect(find.text('Sitto Fatma · 2 parts · 7:45'), findsOneWidget);
    expect(find.text('Kept: 7:45'), findsOneWidget);
    expect(find.text('Only on this phone until you save it.'), findsOneWidget);
    await t.expectAccessible();
  });

  testWidgets('the three actions, play and close report their item', (t) async {
    final log = <String>[];
    await t.pumpApp(_view([_a], log: log));
    await _tall(t);
    await t.tap(find.byKey(const Key('resume_play_a')));
    await t.tap(find.byKey(const Key('resume_from_here_a')));
    await t.tap(find.byKey(const Key('resume_continue_a')));
    await t.tap(find.byKey(const Key('resume_save_a')));
    await t.ensureVisible(find.byKey(const Key('resume_delete_a')));
    await t.tap(find.byKey(const Key('resume_delete_a')));
    await t.tap(find.byKey(const Key('resume_close')));
    expect(log, [
      'play a',
      'continue a',
      'continue a',
      'save a',
      'delete a',
      'close',
    ]);
  });

  testWidgets('no narrator: neutral title and meta line', (t) async {
    await t.pumpApp(_view([_b]));
    expect(find.text('Your recording is safe'), findsOneWidget);
    expect(find.text('1 part · 1:01'), findsOneWidget);
  });

  testWidgets('several recordings: each row has its own actions', (t) async {
    final log = <String>[];
    await t.pumpApp(_view([_a, _b], log: log));
    await _tall(t);
    expect(find.byKey(const Key('resume_continue_a')), findsOneWidget);
    await t.scrollUntilVisible(
      find.byKey(const Key('resume_save_b')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('resume_continue_b')), findsOneWidget);
    await t.ensureVisible(find.byKey(const Key('resume_save_b')));
    await t.pump();
    await t.tap(find.byKey(const Key('resume_save_b')));
    expect(log, ['save b']);
  });

  testWidgets('playing shows the pause label', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpApp(_view([_a], playing: 'a'));
    await _tall(t);
    expect(find.bySemanticsLabel(RegExp('Pause')), findsOneWidget);
    expect(find.bySemanticsLabel('Play the whole recording'), findsNothing);
    handle.dispose();
  });

  testWidgets('Arabic: RTL, plural parts and accessible', (t) async {
    await t.pumpApp(_view([_a, _b]), locale: const Locale('ar'));
    await _tall(t);
    expect(find.text('تسجيلك مع Sitto Fatma محفوظ'), findsOneWidget);
    expect(find.text('Sitto Fatma · جزءين · 7:45'), findsOneWidget);
    expect(find.text('جزء واحد · 1:01'), findsOneWidget);
    expect(
      Directionality.of(t.element(find.text('كمّل التسجيل').first)),
      TextDirection.rtl,
    );
    await t.expectAccessible();
  });

  testWidgets('the unfinished segment is drawn dashed', (t) async {
    await t.pumpApp(_view([_a]));
    await _tall(t);
    expect(find.byKey(const Key('resume_dashed_segment')), findsOneWidget);
  });

  for (final locale in const ['en', 'ar']) {
    testWidgets(
      'narrow screen at 160% text: nothing overflows or is cut ($locale)',
      (t) async {
        await t.pumpApp(_view([_a]), locale: Locale(locale));
        t.view
          ..physicalSize = const Size(640, 1800)
          ..devicePixelRatio = 2;
        t.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        await t.pump();
        expect(t.takeException(), isNull);
        final link = find.byKey(const Key('resume_from_here_a'));
        await t.scrollUntilVisible(
          link,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        final text = find.descendant(of: link, matching: find.byType(Text));
        final box = t.renderObject<RenderParagraph>(text);
        expect(box.didExceedMaxLines, isFalse);
        expect(link, findsOneWidget);
      },
    );
  }
}
