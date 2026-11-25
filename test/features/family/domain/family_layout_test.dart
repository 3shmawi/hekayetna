import 'dart:math';
import 'dart:ui';

import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/family/domain/family_graph.dart';
import 'package:family_stories/features/family/domain/family_layout.dart';
import 'package:flutter_test/flutter_test.dart';

import 'family_fixtures.dart';

FamilyGraph graphOf(List<String> ids, List<Relationship> rels, {String? me}) =>
    FamilyGraph.build(
      persons: [for (final i in ids) person(i)],
      relationships: rels,
      meId: me,
    );

/// True when an axis-aligned rope segment crosses the inside of [r].
bool crosses(Offset a, Offset b, Rect r) {
  final seg = Rect.fromPoints(a, b);
  // A zero-width segment still counts: compare against the open interior.
  return seg.right > r.left &&
      seg.left < r.right &&
      seg.bottom > r.top &&
      seg.top < r.bottom;
}

void expectClean(FamilyLayout l) {
  for (final rope in l.ropes) {
    for (var i = 0; i + 1 < rope.points.length; i++) {
      for (final n in l.nodes.values) {
        expect(
          crosses(rope.points[i], rope.points[i + 1], n.label),
          isFalse,
          reason: '${rope.kind} rope crosses the label of ${n.id}',
        );
      }
    }
  }
  final boxes = l.nodes.values.toList();
  for (var i = 0; i < boxes.length; i++) {
    for (var j = i + 1; j < boxes.length; j++) {
      expect(
        boxes[i].bounds.overlaps(boxes[j].bounds),
        isFalse,
        reason: '${boxes[i].id} overlaps ${boxes[j].id}',
      );
    }
  }
}

void main() {
  group('couples', () {
    final g = graphOf(
      ['a', 'b', 'k1', 'k2', 'k3'],
      [
        spouses('a', 'b'),
        parentOf('a', 'k1'),
        parentOf('b', 'k1'),
        parentOf('a', 'k2'),
        parentOf('b', 'k2'),
        parentOf('a', 'k3'),
        parentOf('b', 'k3'),
      ],
    );

    test('a couple sits side by side with a clear gap between the labels', () {
      final l = layoutFamily(g, labelWidth: (_) => 120);
      final a = l.nodes['a']!;
      final b = l.nodes['b']!;
      expect(a.center.dy, b.center.dy);
      final gap = (a.center.dx - b.center.dx).abs() - 120;
      expect(gap, greaterThanOrEqualTo(24));
    });

    test('the spouse distance grows with the widest label', () {
      final l = layoutFamily(g, labelWidth: (id) => id == 'b' ? 200 : 120);
      final d = (l.nodes['a']!.center.dx - l.nodes['b']!.center.dx).abs();
      expect(d, greaterThanOrEqualTo(200 + 24));
    });

    test('children are centred under the knot, one row down', () {
      final l = layoutFamily(g);
      final knot = (l.nodes['a']!.center.dx + l.nodes['b']!.center.dx) / 2;
      final xs = [
        for (final k in ['k1', 'k2', 'k3']) l.nodes[k]!.center.dx,
      ];
      expect((xs.first + xs.last) / 2, closeTo(knot, 0.001));
      for (final k in ['k1', 'k2', 'k3']) {
        expect(
          l.nodes[k]!.center.dy - l.nodes['a']!.center.dy,
          TreeMetrics.rowHeight,
        );
      }
    });

    test('siblings are at least 140 px apart', () {
      final l = layoutFamily(g);
      final xs = [
        for (final k in ['k1', 'k2', 'k3']) l.nodes[k]!.center.dx,
      ]..sort();
      expect(xs[1] - xs[0], greaterThanOrEqualTo(140));
      expect(xs[2] - xs[1], greaterThanOrEqualTo(140));
    });

    test('knot drops through the gap between the labels, bus in the band', () {
      final l = layoutFamily(g);
      expectClean(l);
      final knot = (l.nodes['a']!.center.dx + l.nodes['b']!.center.dx) / 2;
      final trunk = l.ropes.firstWhere(
        (r) => r.kind == RopeKind.trunk && r.points.first.dx == knot,
      );
      // Starts at the circles' centre height, between the two circles.
      expect(trunk.points.first.dy, l.nodes['a']!.center.dy);
      final busY = trunk.points.last.dy;
      expect(busY, greaterThan(l.nodes['a']!.label.bottom));
      expect(busY, lessThan(l.nodes['k1']!.center.dy - TreeMetrics.radius));
    });

    test('there is a couple rope, a drop and a pill per child', () {
      final l = layoutFamily(g);
      expect(l.ropes.where((r) => r.kind == RopeKind.couple), hasLength(1));
      expect(l.ropes.where((r) => r.kind == RopeKind.drop), hasLength(3));
      expect(l.pills.where((p) => p.kind == PillKind.child), hasLength(3));
      expect(l.pills.where((p) => p.kind == PillKind.couple), hasLength(1));
    });
  });

  test('a single parent: the rope starts under the label, no knot', () {
    final g = graphOf(
      ['p', 'c1', 'c2'],
      [parentOf('p', 'c1'), parentOf('p', 'c2')],
    );
    final l = layoutFamily(g);
    expectClean(l);
    final p = l.nodes['p']!;
    final start = l.ropes.firstWhere((r) => r.kind == RopeKind.trunk);
    expect(start.points.first, Offset(p.center.dx, p.label.bottom));
    expect(l.pills.where((q) => q.kind == PillKind.couple), isEmpty);
  });

  test('remarriage: one person with two spouses, children under each knot', () {
    final g = graphOf(
      ['b', 'a', 'c', 'k1', 'k2'],
      [
        spouses('b', 'a'),
        spouses('b', 'c'),
        parentOf('b', 'k1'),
        parentOf('a', 'k1'),
        parentOf('b', 'k2'),
        parentOf('c', 'k2'),
      ],
    );
    final l = layoutFamily(g);
    expectClean(l);
    expect(l.nodes['a']!.center.dy, l.nodes['b']!.center.dy);
    expect(l.nodes['c']!.center.dy, l.nodes['b']!.center.dy);
    // The two couple ropes exist and the children are on the next row.
    expect(l.ropes.where((r) => r.kind == RopeKind.couple), hasLength(2));
    expect(l.nodes['k1']!.center.dy, greaterThan(l.nodes['b']!.center.dy));
    expect(
      (l.nodes['k1']!.center.dx - l.nodes['k2']!.center.dx).abs(),
      greaterThanOrEqualTo(140),
    );
  });

  test('siblings without parents share a row, no rope', () {
    final g = graphOf(
      ['x', 'y', 'z'],
      [siblings('x', 'y'), siblings('y', 'z')],
    );
    final l = layoutFamily(g);
    expectClean(l);
    expect(l.ropes, isEmpty);
    final ys = {for (final n in l.nodes.values) n.center.dy};
    expect(ys, hasLength(1));
  });

  test('disconnected people go in a final row below everyone else', () {
    final g = graphOf(['p', 'c', 'lone1', 'lone2'], [parentOf('p', 'c')]);
    final l = layoutFamily(g);
    expectClean(l);
    expect(l.unconnected, ['lone1', 'lone2']);
    final lowest = l.nodes['c']!.center.dy;
    expect(l.nodes['lone1']!.center.dy, greaterThan(lowest));
    expect(l.nodes['lone2']!.center.dy, l.nodes['lone1']!.center.dy);
    expect(l.unconnectedTop, greaterThan(l.nodes['c']!.label.bottom - 1));
  });

  test('pending relationships are drawn dashed, not as confirmed ropes', () {
    final g = graphOf(
      ['p', 'c'],
      [parentOf('p', 'c', RelationshipStatus.pending)],
    );
    final l = layoutFamily(g);
    // Both people are unconnected in the confirmed graph: they wait in the
    // last row and no rope is drawn across the tree.
    expect(l.unconnected, containsAll(['p', 'c']));
    expect(l.ropes, isEmpty);
  });

  test('a pending relationship between placed people is a dashed rope', () {
    final g = graphOf(
      ['p', 'q', 'c', 'x'],
      [
        spouses('p', 'q'),
        parentOf('p', 'c'),
        parentOf('q', 'c'),
        // x is connected (sibling of c) and pending as a child of p.
        siblings('c', 'x'),
        parentOf('p', 'x', RelationshipStatus.pending),
      ],
    );
    final l = layoutFamily(g);
    expectClean(l);
    final pending = l.ropes.where((r) => r.pending).toList();
    expect(pending, hasLength(1));
    expect(pending.single.child, 'x');
  });

  test('the whole big family lays out cleanly with the cousins in place', () {
    final fam = bigFamily();
    final g = FamilyGraph.build(
      persons: fam.persons,
      relationships: fam.rels,
      meId: 'me',
    );
    final l = layoutFamily(g);
    expectClean(l);
    // Grandparents above parents above me.
    expect(l.nodes['sitto']!.center.dy, lessThan(l.nodes['mama']!.center.dy));
    expect(l.nodes['mama']!.center.dy, lessThan(l.nodes['me']!.center.dy));
    expect(l.nodes['ggm']!.center.dy, lessThan(l.nodes['sitto']!.center.dy));
  });

  test('mirrored flips x and keeps the geometry clean', () {
    final fam = bigFamily();
    final g = FamilyGraph.build(persons: fam.persons, relationships: fam.rels);
    final l = layoutFamily(g);
    final m = l.mirrored();
    expectClean(m);
    final width = l.bounds.right + l.bounds.left;
    for (final id in l.nodes.keys) {
      expect(
        m.nodes[id]!.center.dx,
        closeTo(width - l.nodes[id]!.center.dx, 0.001),
      );
      expect(m.nodes[id]!.center.dy, l.nodes[id]!.center.dy);
    }
    // Parents stay to the right of what was their left.
    expect(
      m.nodes['sitto']!.center.dx > m.nodes['giddu']!.center.dx,
      l.nodes['sitto']!.center.dx < l.nodes['giddu']!.center.dx,
    );
  });

  test('layout is deterministic', () {
    final fam = bigFamily();
    final g = FamilyGraph.build(persons: fam.persons, relationships: fam.rels);
    final a = layoutFamily(g);
    final b = layoutFamily(g);
    for (final id in a.nodes.keys) {
      expect(a.nodes[id]!.center, b.nodes[id]!.center);
    }
  });

  test('300 generated people: no rope under a label, nothing overlaps', () {
    final rnd = Random(7);
    final persons = <Person>[];
    final rels = <Relationship>[];
    var n = 0;
    String add() {
      final id = 'g${n++}';
      persons.add(person(id, n.isEven ? f : m));
      return id;
    }

    // Couples with 0-4 children; children marry in a new person.
    final queue = <(String, String)>[];
    final a0 = add();
    final b0 = add();
    rels.add(spouses(a0, b0));
    queue.add((a0, b0));
    while (n < 300 && queue.isNotEmpty) {
      final (a, b) = queue.removeAt(0);
      final kids = 1 + rnd.nextInt(4);
      for (var i = 0; i < kids && n < 298; i++) {
        final c = add();
        rels
          ..add(parentOf(a, c))
          ..add(parentOf(b, c));
        if (rnd.nextBool()) {
          final s = add();
          rels.add(spouses(c, s));
          queue.add((c, s));
        } else {
          queue.add((c, c));
        }
      }
    }
    // Single-person "couples" have no spouse: drop their self entries.
    final g = FamilyGraph.build(persons: persons, relationships: rels);
    expect(persons.length, greaterThanOrEqualTo(290));
    final l = layoutFamily(g, labelWidth: (id) => 90.0 + (id.hashCode % 50));
    expectClean(l);
  });
}
