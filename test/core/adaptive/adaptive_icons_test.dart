import 'package:family_stories/core/adaptive/adaptive.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // IconData must stay const so release builds can tree-shake the icon
  // fonts, so the mirrored icons keep literal codepoints. These checks fail
  // when the SDK moves a glyph instead of silently drawing another one.
  testWidgets('hand-typed codepoints match the SDK constants', (t) async {
    late IconData materialPlay;
    await t.pumpWidget(
      Builder(
        builder: (context) {
          materialPlay = AdaptiveIcons.playForTest(context);
          return const SizedBox();
        },
      ),
    );
    expect(materialPlay.codePoint, Icons.play_arrow.codePoint);
    expect(materialPlay.fontFamily, Icons.play_arrow.fontFamily);
    expect(materialPlay.matchTextDirection, isTrue);
    expect(
      AdaptiveIcons.cupertinoPlayForTest.codePoint,
      CupertinoIcons.play_fill.codePoint,
    );
    expect(
      AdaptiveIcons.forwardForTest.codePoint,
      CupertinoIcons.forward.codePoint,
    );
    expect(AdaptiveIcons.cupertinoPlayForTest.matchTextDirection, isTrue);
    expect(AdaptiveIcons.forwardForTest.matchTextDirection, isTrue);
  });
}
