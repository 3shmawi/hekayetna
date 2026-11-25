import 'package:family_stories/features/family/domain/family_graph.dart';
import 'package:family_stories/features/family/domain/family_layout.dart';
import 'package:family_stories/features/family/presentation/family_tree_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';
import '../domain/family_fixtures.dart';

FamilyGraph bigGraph() {
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

Future<
  ({
    FamilyTreeController controller,
    List<String> taps,
    List<TreeZoomVia> zooms,
  })
>
_pump(
  WidgetTester t,
  FamilyGraph g, {
  Locale locale = const Locale('en'),
  String? selected,
}) async {
  final controller = FamilyTreeController();
  final taps = <String>[];
  final zooms = <TreeZoomVia>[];
  await t.pumpApp(
    Scaffold(
      body: FamilyTreeCanvas(
        graph: g,
        controller: controller,
        selectedId: selected,
        onTapPerson: taps.add,
        onLongPressPerson: (_) {},
        onZoomed: zooms.add,
      ),
    ),
    locale: locale,
  );
  await t.pump();
  await t.pump();
  return (controller: controller, taps: taps, zooms: zooms);
}

Finder node(String name) => find.text(name);

void main() {
  testWidgets('opens centred on me at 100%', (t) async {
    final r = await _pump(t, bigGraph());
    expect(r.controller.scale, closeTo(1, 0.001));
    final c = t.getCenter(find.bySemanticsLabel(RegExp('^me, You')));
    final view = t.getSize(find.byType(FamilyTreeCanvas));
    expect(c.dx, closeTo(view.width / 2, 40));
  });

  testWidgets('zoom buttons clamp between 50% and 180%', (t) async {
    final r = await _pump(t, bigGraph());
    for (var i = 0; i < 10; i++) {
      await t.tap(find.byTooltip('Zoom in'));
      await t.pump();
    }
    expect(r.controller.scale, closeTo(kTreeMaxScale, 0.001));
    for (var i = 0; i < 20; i++) {
      await t.tap(find.byTooltip('Zoom out'));
      await t.pump();
    }
    expect(r.controller.scale, closeTo(kTreeMinScale, 0.001));
    expect(r.zooms, everyElement(TreeZoomVia.button));
  });

  testWidgets('Fit shows the whole family, Center returns to me at 100%', (
    t,
  ) async {
    final r = await _pump(t, bigGraph());
    await t.tap(find.byTooltip('Show the whole family'));
    await t.pump();
    expect(r.controller.scale, lessThan(1));
    expect(r.zooms.last, TreeZoomVia.fit);
    await t.tap(find.byTooltip('Center on me'));
    await t.pump();
    expect(r.controller.scale, closeTo(1, 0.001));
    expect(r.zooms.last, TreeZoomVia.center);
  });

  testWidgets('double tap zooms in 1.5x', (t) async {
    final r = await _pump(t, bigGraph());
    final at =
        t.getTopLeft(find.byType(FamilyTreeCanvas)) + const Offset(40, 300);
    await t.tapAt(at);
    await t.pump(const Duration(milliseconds: 40));
    await t.tapAt(at);
    await t.pumpAndSettle();
    expect(r.controller.scale, closeTo(1.5, 0.01));
  });

  testWidgets('search-to-person: focusOn centres and zooms to them', (t) async {
    final r = await _pump(t, bigGraph());
    r.controller.focusOn('khalSon');
    await t.pump();
    expect(r.controller.scale, closeTo(1.2, 0.001));
    final c = t.getCenter(find.bySemanticsLabel(RegExp('^khalSon')));
    final view = t.getSize(find.byType(FamilyTreeCanvas));
    expect(c.dx, closeTo(view.width / 2, 60));
    expect(c.dy, closeTo(view.height / 2, 90));
  });

  testWidgets('tapping a node reports it; dragging never does', (t) async {
    final handle = t.ensureSemantics();
    final r = await _pump(t, bigGraph());
    await t.tap(find.text('me').first);
    await t.pump();
    expect(r.taps, ['me']);
    r.taps.clear();
    await t.drag(find.text('me').first, const Offset(-120, 0));
    await t.pumpAndSettle();
    expect(r.taps, isEmpty);
    handle.dispose();
  });

  testWidgets('semantics say name, relation and story count', (t) async {
    final handle = t.ensureSemantics();
    await _pump(t, bigGraph());
    Finder r(String s) => find.bySemanticsLabel(s);
    expect(r('mama, Mother, 1 story'), findsOneWidget);
    expect(r('me, You, no stories yet'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('pills and relation lines hide below 75% zoom', (t) async {
    final r = await _pump(t, bigGraph());
    expect(find.text('Married'), findsWidgets);
    expect(find.text('Mother'), findsWidgets);
    r.controller.zoomBy(0.6);
    await t.pump();
    expect(find.text('Married'), findsNothing);
    expect(find.text('Mother'), findsNothing);
  });

  testWidgets('a 300-person tree only builds what is on screen', (t) async {
    final persons = [
      for (var i = 0; i < 300; i++) person('p$i', i.isEven ? f : m),
    ];
    final rels = [
      for (var i = 1; i < 300; i++) parentOf('p${(i - 1) ~/ 3}', 'p$i'),
    ];
    final g = FamilyGraph.build(
      persons: persons,
      relationships: rels,
      meId: 'p0',
    );
    await _pump(t, g);
    final built = find.byType(Semantics).evaluate().length;
    expect(
      find.textContaining(RegExp(r'^p\d+$')).evaluate().length,
      lessThan(80),
    );
    expect(built, greaterThan(0));
  });

  testWidgets('RTL mirrors: the start side is the right', (t) async {
    final g = bigGraph();
    await _pump(t, g, locale: const Locale('ar'));
    final sitto = t.getCenter(find.bySemanticsLabel(RegExp('^sitto')));
    final giddu = t.getCenter(find.bySemanticsLabel(RegExp('^giddu')));
    // LTR layout puts the first spouse on the left; Arabic flips it.
    final ltr = layoutFamily(g);
    expect(
      sitto.dx < giddu.dx,
      ltr.nodes['sitto']!.center.dx > ltr.nodes['giddu']!.center.dx,
    );
  });

  testWidgets('accessibility: tap targets, labels and contrast', (t) async {
    await _pump(t, bigGraph());
    await t.expectAccessible();
  });

  testWidgets('selecting a person dims ropes off the path to me', (t) async {
    final g = bigGraph();
    final l = layoutFamily(g);
    final path = g.pathBetween('khalSon', 'me')!;
    final lit = ropesOnPath(l, path);
    expect(lit, isNotEmpty);
    expect(lit.length, lessThan(l.ropes.length));
    // Every lit rope belongs to a family or couple on the path.
    for (final i in lit) {
      final rope = l.ropes[i];
      final people = path.people.toSet();
      expect(rope.parents.any(people.contains) || rope.child != null, isTrue);
    }
    await _pump(t, g, selected: 'khalSon');
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
