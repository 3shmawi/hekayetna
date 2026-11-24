import 'package:family_stories/core/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

Widget _card({required String topic, required String date}) => Padding(
  padding: const EdgeInsets.all(16),
  child: StoryCard(
    title: 'The first Om Ali',
    narratorName: 'Sitto Amina',
    dateLabel: date,
    duration: '2:34',
    topicLabel: topic,
    isSample: true,
    onOpen: () {},
    onPlay: () {},
  ),
);

RenderParagraph _paragraph(WidgetTester t, String text) =>
    t.renderObject<RenderParagraph>(find.text(text));

void main() {
  // Real glyph widths: the default test font is far wider than the app's.
  setUp(loadAppFonts);

  for (final locale in const [Locale('en'), Locale('ar')]) {
    final ar = locale.languageCode == 'ar';
    final topic = ar
        ? 'رمضان والعيد والعادات العائلية'
        : 'Ramadan, Eid and family traditions';
    final date = ar ? 'رمضان، أواخر الخمسينيات' : 'Ramadan, late 1950s';

    testWidgets(
      'long topic and date wrap without clipping (${locale.languageCode})',
      (t) async {
        await t.pumpApp(
          _card(topic: topic, date: date),
          locale: locale,
        );
        expect(t.takeException(), isNull);
        // Both lines of the topic chip are shown, not cut at the first line.
        expect(_paragraph(t, topic).didExceedMaxLines, isFalse);
        final meta = find.textContaining('Sitto Amina');
        expect(meta, findsOneWidget);
        expect(
          t.renderObject<RenderParagraph>(meta).didExceedMaxLines,
          isFalse,
        );
      },
    );

    testWidgets(
      'large text scale keeps the card readable (${locale.languageCode})',
      (t) async {
        t.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        await t.pumpApp(
          _card(topic: topic, date: date),
          locale: locale,
        );
        expect(t.takeException(), isNull);
        expect(find.byType(StoryCard), findsOneWidget);
      },
    );
  }
}
