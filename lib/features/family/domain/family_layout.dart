import 'dart:ui';

import 'package:family_stories/features/family/domain/family_graph.dart';

/// Geometry constants, in logical pixels at 100% zoom (spec 05).
class TreeMetrics {
  const TreeMetrics._();

  static const rowHeight = 220.0;
  static const avatar = 68.0;
  static const double radius = avatar / 2;

  /// Space between the bottom of a circle and the top of its label.
  static const labelGap = 6.0;
  static const labelHeight = 40.0;
  static const defaultLabelWidth = 120.0;
  static const spouseGap = 24.0;
  static const minSiblingDistance = 140.0;
  static const rootGap = 80.0;
  static const componentGap = 160.0;
  static const margin = 100.0;
  static const cornerRadius = 12.0;

  /// Where the bus line sits below a parent row's circle centre: the middle
  /// of the empty band between the parents' labels and the children's
  /// circles.
  static const double busDrop =
      ((radius + labelGap + labelHeight) + (rowHeight - radius)) / 2;
}

enum RopeKind { couple, trunk, drop }

/// An orthogonal rope. Corners are rounded by the painter; the polyline is
/// what tests check against the label rectangles.
class Rope {
  const Rope({
    required this.kind,
    required this.points,
    required this.pending,
    required this.parents,
    this.child,
  });

  final RopeKind kind;
  final List<Offset> points;
  final bool pending;

  /// couple: the two partners. trunk and drop: the parents of the family.
  final List<String> parents;

  /// drop only: the child this rope ends at.
  final String? child;
}

enum PillKind { child, couple }

/// A small label sitting on a rope ("daughter", "married").
class RopePill {
  const RopePill({
    required this.kind,
    required this.at,
    required this.pending,
    required this.personId,
  });

  final PillKind kind;
  final Offset at;
  final bool pending;

  /// child: the child the pill labels. couple: one of the partners.
  final String personId;
}

class NodeLayout {
  const NodeLayout({
    required this.id,
    required this.center,
    required this.label,
    required this.level,
  });

  final String id;

  /// Centre of the avatar circle.
  final Offset center;

  /// The name + relation text under the circle.
  final Rect label;
  final int level;

  Rect get circle =>
      Rect.fromCircle(center: center, radius: TreeMetrics.radius);

  /// Everything the node paints: circle and label.
  Rect get bounds => circle.expandToInclude(label);
}

class FamilyLayout {
  const FamilyLayout({
    required this.nodes,
    required this.ropes,
    required this.pills,
    required this.bounds,
    required this.unconnected,
    required this.unconnectedTop,
  });

  final Map<String, NodeLayout> nodes;
  final List<Rope> ropes;
  final List<RopePill> pills;
  final Rect bounds;

  /// Ids in the final "Not connected yet" row, in display order.
  final List<String> unconnected;

  /// Top of the "Not connected yet" row (for its heading).
  final double unconnectedTop;
}

/// Lays the family out as generation rows with couples side by side,
/// children centred under their parents' knot, and orthogonal ropes that
/// never pass under a label. Pure and deterministic.
FamilyLayout layoutFamily(
  FamilyGraph g, {
  double Function(String id)? labelWidth,
}) {
  return _Layouter(g, labelWidth ?? (_) => TreeMetrics.defaultLabelWidth).run();
}

class _Placed {
  _Placed(this.id, this.dx);
  final String id;
  double dx;
}

class _Block {
  _Block(this.placed, this.left, this.right);

  /// Everyone in the subtree with x relative to the block's pivot person.
  final List<_Placed> placed;

  /// Extent to the left and right of the pivot (both >= 0).
  double left;
  double right;
}

class _Unit {
  _Unit(this.members);
  final List<String> members;
}

class _Layouter {
  _Layouter(this.g, this.labelWidthOf);

  final FamilyGraph g;
  final double Function(String) labelWidthOf;

  final _levels = <String, int>{};
  final _unitOf = <String, _Unit>{};
  final _placedUnits = <_Unit>{};
  final _familiesByHost = <String, List<List<String>>>{};
  final _x = <String, double>{};

  double w(String id) {
    final v = labelWidthOf(id);
    return v < TreeMetrics.avatar ? TreeMetrics.avatar : v;
  }

  /// Centre-to-centre distance for two neighbours that are not a couple.
  double slot(String id) {
    final s = w(id) + TreeMetrics.spouseGap;
    return s < TreeMetrics.minSiblingDistance
        ? TreeMetrics.minSiblingDistance
        : s;
  }

  FamilyLayout run() {
    final ids = g.persons.keys.toList()..sort();
    final connected = [
      for (final id in ids)
        if (g.isConnected(id)) id,
    ];
    final unconnected = [
      for (final id in ids)
        if (!g.isConnected(id)) id,
    ];

    _assignLevels(connected);
    _buildUnits(connected);
    _indexFamilies(connected);

    // Components, the one holding "me" first, then by size and id.
    final components = _components(connected);
    var cursor = TreeMetrics.margin;
    for (final comp in components) {
      final roots = _rootUnits(comp);
      var first = true;
      for (final u in roots) {
        if (_placedUnits.contains(u)) continue;
        final block = _layoutUnit(u, u.members.first);
        final pivot = first
            ? cursor + block.left
            : cursor + TreeMetrics.rootGap + block.left;
        for (final p in block.placed) {
          _x[p.id] = pivot + p.dx;
        }
        cursor = pivot + block.right;
        first = false;
      }
      cursor += TreeMetrics.componentGap - TreeMetrics.rootGap;
    }
    // Anything a cyclic or inconsistent graph left unplaced.
    for (final id in connected) {
      if (_x.containsKey(id)) continue;
      final u = _unitOf[id]!;
      if (_placedUnits.contains(u)) continue;
      final block = _layoutUnit(u, id);
      final pivot = cursor + TreeMetrics.rootGap + block.left;
      for (final p in block.placed) {
        _x[p.id] = pivot + p.dx;
      }
      cursor = pivot + block.right;
    }
    return _finish(connected, unconnected);
  }

  // ---- generations --------------------------------------------------------

  void _assignLevels(List<String> connected) {
    final raw = <String, int>{};
    final comps = <List<String>>[];
    for (final start in connected) {
      if (raw.containsKey(start)) continue;
      raw[start] = 0;
      final comp = [start];
      final queue = [start];
      for (var i = 0; i < queue.length; i++) {
        final id = queue[i];
        for (final (step, n) in g.neighbours(id)) {
          if (raw.containsKey(n)) continue;
          raw[n] =
              raw[id]! +
              switch (step) {
                KinStep.up => -1,
                KinStep.down => 1,
                _ => 0,
              };
          queue.add(n);
          comp.add(n);
        }
      }
      comps.add(comp);
    }
    for (final comp in comps) {
      final min = comp.map((e) => raw[e]!).reduce((a, b) => a < b ? a : b);
      for (final id in comp) {
        _levels[id] = raw[id]! - min;
      }
    }
  }

  // ---- units (couples) ----------------------------------------------------

  void _buildUnits(List<String> connected) {
    for (final id in connected) {
      if (_unitOf.containsKey(id)) continue;
      // Walk the spouse graph from an end of the chain.
      final comp = <String>{id};
      final stack = [id];
      while (stack.isNotEmpty) {
        final cur = stack.removeLast();
        for (final s in g.spousesOf(cur)) {
          if (comp.add(s)) stack.add(s);
        }
      }
      final sorted = comp.toList()..sort();
      final start = sorted.firstWhere(
        (e) => g.spousesOf(e).length == 1,
        orElse: () => sorted.first,
      );
      final order = <String>[];
      final seen = <String>{};
      void walk(String cur) {
        if (!seen.add(cur)) return;
        order.add(cur);
        g.spousesOf(cur).forEach(walk);
      }

      walk(start);
      final unit = _Unit(order);
      for (final m in order) {
        _unitOf[m] = unit;
      }
    }
  }

  // ---- families -----------------------------------------------------------

  List<List<String>> _familiesOfPersons(Iterable<String> persons) {
    final keys = <String, List<String>>{};
    for (final p in persons) {
      final parents = g.parentsOf(p);
      if (parents.isEmpty) continue;
      keys.putIfAbsent(parents.join('|'), () => parents);
    }
    return keys.values.toList();
  }

  void _indexFamilies(List<String> connected) {
    for (final f in _familiesOfPersons(connected)) {
      _familiesByHost.putIfAbsent(f.first, () => []).add(f);
    }
  }

  List<String> _childrenOfFamily(List<String> parents) => [
    for (final c in g.childrenOf(parents.first))
      if (_sameList(g.parentsOf(c), parents)) c,
  ];

  bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ---- components and roots ----------------------------------------------

  List<List<String>> _components(List<String> connected) {
    final seen = <String>{};
    final comps = <List<String>>[];
    for (final start in connected) {
      if (!seen.add(start)) continue;
      final comp = [start];
      for (var i = 0; i < comp.length; i++) {
        for (final (_, n) in g.neighbours(comp[i])) {
          if (seen.add(n)) comp.add(n);
        }
      }
      comp.sort();
      comps.add(comp);
    }
    comps.sort((a, b) {
      final am = g.meId != null && a.contains(g.meId) ? 0 : 1;
      final bm = g.meId != null && b.contains(g.meId) ? 0 : 1;
      if (am != bm) return am - bm;
      if (a.length != b.length) return b.length - a.length;
      return a.first.compareTo(b.first);
    });
    return comps;
  }

  List<_Unit> _rootUnits(List<String> comp) {
    final units = <_Unit>[];
    for (final id in comp) {
      final u = _unitOf[id]!;
      if (units.contains(u)) continue;
      final hasParents = u.members.any((m) => g.parentsOf(m).isNotEmpty);
      if (!hasParents) units.add(u);
    }
    return units;
  }

  // ---- block layout -------------------------------------------------------

  _Block _layoutUnit(_Unit unit, String pivot) {
    _placedUnits.add(unit);
    final members = unit.members;
    final pos = <double>[];
    var x = 0.0;
    for (var i = 0; i < members.length; i++) {
      if (i > 0) {
        x +=
            (w(members[i - 1]) > w(members[i])
                ? w(members[i - 1])
                : w(members[i])) +
            TreeMetrics.spouseGap;
      }
      pos.add(x);
    }
    final pivotX = pos[members.indexOf(pivot)];
    for (var i = 0; i < pos.length; i++) {
      pos[i] -= pivotX;
    }
    final index = {for (var i = 0; i < members.length; i++) members[i]: i};

    // Families hosted by this unit, with the x the knot (or parent) is at.
    final groups = <_Group>[];
    for (final m in members) {
      for (final family in _familiesByHost[m] ?? const <List<String>>[]) {
        final kids = [
          for (final c in _childrenOfFamily(family))
            if (!_placedUnits.contains(_unitOf[c])) c,
        ];
        if (kids.isEmpty) continue;
        var desired = pos[index[m]!];
        if (family.length == 2 &&
            index.containsKey(family[0]) &&
            index.containsKey(family[1])) {
          desired = (pos[index[family[0]]!] + pos[index[family[1]]!]) / 2;
        }
        groups.add(_Group(family, kids, desired));
      }
    }
    groups.sort((a, b) => a.desired.compareTo(b.desired));

    // Lay each group's children left to right.
    for (final grp in groups) {
      final blocks = <_Block>[];
      final pivots = <String>[];
      final seenUnits = <_Unit>{};
      for (final c in grp.children) {
        final cu = _unitOf[c]!;
        if (!seenUnits.add(cu) || _placedUnits.contains(cu)) continue;
        blocks.add(_layoutUnit(cu, c));
        pivots.add(c);
      }
      // Children ordered by birth year then name come from the graph's
      // sorted ids; the screen can reorder with birth data later.
      var cursor = 0.0;
      final xs = <double>[];
      for (final b in blocks) {
        cursor += b.left;
        xs.add(cursor);
        cursor += b.right;
      }
      grp
        ..blocks = blocks
        ..pivotXs = xs
        ..width = cursor
        ..left = blocks.isEmpty ? 0 : blocks.first.left
        // Centre of the first and last pivots.
        ..centre = xs.isEmpty ? 0 : (xs.first + xs.last) / 2;
    }

    // Place groups so each centre sits at its knot, pushing right when two
    // would overlap, then shift all together to balance.
    var rightEdge = double.negativeInfinity;
    final offsets = <double>[]; // group origin (its x=0) in unit space
    for (final grp in groups) {
      var origin = grp.desired - grp.centre;
      final leftEdge = origin;
      if (leftEdge < rightEdge) origin += rightEdge - leftEdge;
      offsets.add(origin);
      rightEdge = origin + grp.width;
    }
    if (groups.isNotEmpty) {
      var shift = 0.0;
      for (var i = 0; i < groups.length; i++) {
        shift += groups[i].desired - (offsets[i] + groups[i].centre);
      }
      shift /= groups.length;
      // Shifting everyone by the mean keeps them non-overlapping.
      for (var i = 0; i < offsets.length; i++) {
        offsets[i] += shift;
      }
    }

    final placed = <_Placed>[
      for (var i = 0; i < members.length; i++) _Placed(members[i], pos[i]),
    ];
    var left = 0.0;
    var right = 0.0;
    for (var i = 0; i < members.length; i++) {
      final half = slot(members[i]) / 2;
      if (-pos[i] + half > left) left = -pos[i] + half;
      if (pos[i] + half > right) right = pos[i] + half;
    }
    for (var gi = 0; gi < groups.length; gi++) {
      final grp = groups[gi];
      for (var bi = 0; bi < grp.blocks.length; bi++) {
        final dx = offsets[gi] + grp.pivotXs[bi];
        for (final p in grp.blocks[bi].placed) {
          placed.add(_Placed(p.id, p.dx + dx));
        }
        final l = grp.blocks[bi].left - dx;
        final r = grp.blocks[bi].right + dx;
        if (l > left) left = l;
        if (r > right) right = r;
      }
    }
    return _Block(placed, left, right);
  }

  // ---- final geometry -----------------------------------------------------

  FamilyLayout _finish(List<String> connected, List<String> unconnected) {
    final nodes = <String, NodeLayout>{};
    NodeLayout nodeAt(String id, double cx, double cy, int level) {
      final lw = w(id);
      return NodeLayout(
        id: id,
        center: Offset(cx, cy),
        level: level,
        label: Rect.fromLTWH(
          cx - lw / 2,
          cy + TreeMetrics.radius + TreeMetrics.labelGap,
          lw,
          TreeMetrics.labelHeight,
        ),
      );
    }

    double cyOfLevel(int level) =>
        TreeMetrics.margin + level * TreeMetrics.rowHeight;

    var maxLevel = 0;
    for (final id in connected) {
      final level = _levels[id]!;
      if (level > maxLevel) maxLevel = level;
      nodes[id] = nodeAt(
        id,
        _x[id] ?? TreeMetrics.margin,
        cyOfLevel(level),
        level,
      );
    }

    // The "Not connected yet" row.
    final rowLevel = connected.isEmpty ? 0 : maxLevel + 1;
    final unconnectedTop = cyOfLevel(rowLevel) - TreeMetrics.radius - 40;
    var ux = TreeMetrics.margin;
    for (final id in unconnected) {
      ux += slot(id) / 2;
      nodes[id] = nodeAt(id, ux, cyOfLevel(rowLevel) + 20, rowLevel);
      ux += slot(id) / 2;
    }

    final ropes = <Rope>[];
    final pills = <RopePill>[];

    // Couples.
    final drawnCouples = <String>{};
    for (final u in _unitOf.values.toSet()) {
      for (var i = 0; i + 1 < u.members.length; i++) {
        final a = nodes[u.members[i]]!;
        final b = nodes[u.members[i + 1]]!;
        if (!g.spousesOf(a.id).contains(b.id)) continue;
        if (!drawnCouples.add('${a.id}|${b.id}')) continue;
        final y = a.center.dy;
        ropes.add(
          Rope(
            kind: RopeKind.couple,
            points: [
              Offset(a.center.dx + TreeMetrics.radius, y),
              Offset(b.center.dx - TreeMetrics.radius, y),
            ],
            pending: false,
            parents: [a.id, b.id],
          ),
        );
        pills.add(
          RopePill(
            kind: PillKind.couple,
            at: Offset((a.center.dx + b.center.dx) / 2, y),
            pending: false,
            personId: a.id,
          ),
        );
      }
    }

    // Families: knot (or label start), trunk to the bus, drops to children.
    final families = _familiesOfPersons(connected);
    for (final family in families) {
      final kids = [
        for (final c in _childrenOfFamily(family))
          if (nodes.containsKey(c)) c,
      ];
      if (kids.isEmpty) continue;
      final parents = [for (final p in family) nodes[p]!];
      final parentY = parents
          .map((p) => p.center.dy)
          .reduce((a, b) => a < b ? a : b);
      final busY = parentY + TreeMetrics.busDrop;
      final trunkTops = <Offset>[];
      if (family.length == 2 &&
          g.spousesOf(family[0]).contains(family[1]) &&
          parents[0].center.dy == parents[1].center.dy &&
          (parents[0].center.dx - parents[1].center.dx).abs() > 0) {
        final knotX = (parents[0].center.dx + parents[1].center.dx) / 2;
        trunkTops.add(Offset(knotX, parents[0].center.dy));
      } else {
        for (final p in parents) {
          trunkTops.add(Offset(p.center.dx, p.label.bottom));
        }
      }
      final kidXs = [for (final c in kids) nodes[c]!.center.dx];
      final allXs = [...kidXs, ...trunkTops.map((t) => t.dx)]..sort();
      for (final t in trunkTops) {
        ropes.add(
          Rope(
            kind: RopeKind.trunk,
            points: [t, Offset(t.dx, busY)],
            pending: false,
            parents: family,
          ),
        );
      }
      if (allXs.last > allXs.first) {
        ropes.add(
          Rope(
            kind: RopeKind.trunk,
            points: [Offset(allXs.first, busY), Offset(allXs.last, busY)],
            pending: false,
            parents: family,
          ),
        );
      }
      for (final c in kids) {
        final n = nodes[c]!;
        final top = Offset(n.center.dx, n.center.dy - TreeMetrics.radius);
        ropes.add(
          Rope(
            kind: RopeKind.drop,
            points: [Offset(n.center.dx, busY), top],
            pending: false,
            parents: family,
            child: c,
          ),
        );
        pills.add(
          RopePill(
            kind: PillKind.child,
            at: Offset(n.center.dx, (busY + top.dy) / 2),
            pending: false,
            personId: c,
          ),
        );
      }
    }

    // Pending relationships: dashed, never used for kinship.
    for (final e in g.pending) {
      final a = nodes[e.a];
      final b = nodes[e.b];
      if (a == null || b == null) continue;
      // A person in the "Not connected yet" row has no place in the tree,
      // and a rope across other rows would run under labels.
      if (!g.isConnected(e.a) || !g.isConnected(e.b)) continue;
      switch (e.kind) {
        case PendingKind.spouse:
        case PendingKind.sibling:
          final y = a.center.dy;
          final left = a.center.dx <= b.center.dx ? a : b;
          final right = identical(left, a) ? b : a;
          if (a.center.dy == b.center.dy) {
            ropes.add(
              Rope(
                kind: RopeKind.couple,
                points: [
                  Offset(left.center.dx + TreeMetrics.radius, y),
                  Offset(right.center.dx - TreeMetrics.radius, y),
                ],
                pending: true,
                parents: [e.a, e.b],
              ),
            );
            if (e.kind == PendingKind.spouse) {
              pills.add(
                RopePill(
                  kind: PillKind.couple,
                  at: Offset((a.center.dx + b.center.dx) / 2, y),
                  pending: true,
                  personId: e.a,
                ),
              );
            }
          }
        case PendingKind.parentChild:
          if (b.level != a.level + 1) continue;
          final busY = a.center.dy + TreeMetrics.busDrop;
          final top = Offset(b.center.dx, b.center.dy - TreeMetrics.radius);
          ropes.add(
            Rope(
              kind: RopeKind.drop,
              points: [
                Offset(a.center.dx, a.label.bottom),
                Offset(a.center.dx, busY),
                Offset(b.center.dx, busY),
                top,
              ],
              pending: true,
              parents: [e.a],
              child: e.b,
            ),
          );
          pills.add(
            RopePill(
              kind: PillKind.child,
              at: Offset(b.center.dx, (busY + top.dy) / 2),
              pending: true,
              personId: e.b,
            ),
          );
      }
    }

    var bounds = const Rect.fromLTWH(
      0,
      0,
      TreeMetrics.margin * 2,
      TreeMetrics.margin * 2,
    );
    for (final n in nodes.values) {
      bounds = bounds.expandToInclude(n.bounds.inflate(TreeMetrics.margin));
    }
    return FamilyLayout(
      nodes: nodes,
      ropes: ropes,
      pills: pills,
      bounds: bounds,
      unconnected: unconnected,
      unconnectedTop: unconnectedTop,
    );
  }
}

class _Group {
  _Group(this.family, this.children, this.desired);

  final List<String> family;
  final List<String> children;
  final double desired;
  List<_Block> blocks = const [];
  List<double> pivotXs = const [];
  double width = 0;
  double left = 0;
  double centre = 0;
}
