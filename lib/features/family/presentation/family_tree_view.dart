import 'dart:math' as math;

import 'package:family_stories/core/theme/app_colors.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:flutter/material.dart';

/// The family tree: persons as nodes, confirmed relationships as lines,
/// pending ones dashed. Account-linked persons are filled; people without
/// accounts stay outlined. Nodes spring in and lines draw progressively;
/// the whole animation is skipped when the system asks for no motion.
///
/// Layout is intentionally simple (generations in rows, spouses adjacent).
/// The list remains the primary directory; this is a visual companion.
class FamilyTreeView extends StatefulWidget {
  const FamilyTreeView({
    required this.persons,
    required this.relationships,
    this.onTapPerson,
    super.key,
  });

  final List<Person> persons;
  final List<Relationship> relationships;
  final ValueChanged<Person>? onTapPerson;

  @override
  State<FamilyTreeView> createState() => _FamilyTreeViewState();
}

class _FamilyTreeViewState extends State<FamilyTreeView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller.value = 1;
    } else {
      _controller.forward().ignore();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final layout = _TreeLayout.build(
      widget.persons,
      widget.relationships,
      rtl: rtl,
    );
    if (layout.nodes.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Fit the whole tree into the viewport at rest (never upscale):
        // the content is pre-scaled and centered, and InteractiveViewer
        // pans and zooms from there for larger families.
        final rawFit = math.min(
          constraints.maxWidth / layout.size.width,
          constraints.maxHeight / layout.size.height,
        );
        final fit = rawFit > 1 ? 1.0 : rawFit;
        return InteractiveViewer(
          boundaryMargin: const EdgeInsets.all(80),
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Center(
              child: SizedBox(
                width: layout.size.width * fit,
                height: layout.size.height * fit,
                child: Transform.scale(
                  scale: fit,
                  alignment: Alignment.topLeft,
                  child: _treeContent(layout),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _treeContent(_TreeLayout layout) {
    return SizedBox(
      width: layout.size.width,
      height: layout.size.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _TreePainter(
            layout: layout,
            progress: _controller.value,
            lineColor: AppColors.oliveTeal,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final node in layout.nodes) ...[
                Positioned(
                  left: node.center.dx - _TreeLayout.nodeRadius,
                  top: node.center.dy - _TreeLayout.nodeRadius,
                  width: _TreeLayout.nodeRadius * 2,
                  height: _TreeLayout.nodeRadius * 2,
                  child: _TreeNode(
                    node: node,
                    progress: _nodeProgress(node, _controller.value),
                    onTap: widget.onTapPerson == null
                        ? null
                        : () => widget.onTapPerson!(node.person),
                  ),
                ),
                Positioned(
                  left: node.center.dx - _TreeLayout.labelWidth / 2,
                  top: node.center.dy + _TreeLayout.nodeRadius + 6,
                  width: _TreeLayout.labelWidth,
                  child: _TreeNodeLabel(
                    node: node,
                    progress: _nodeProgress(node, _controller.value),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Later generations appear later in the stagger.
  double _nodeProgress(_Node node, double t) {
    final start = 0.12 * node.generation;
    final local = ((t - start) / 0.4).clamp(0.0, 1.0);
    return Curves.easeOutBack.transform(local);
  }
}

class _Node {
  const _Node({
    required this.person,
    required this.center,
    required this.generation,
  });

  final Person person;
  final Offset center;
  final int generation;
}

class _Edge {
  const _Edge(this.from, this.to, {this.pending = false, this.spouse = false});

  final Offset from;
  final Offset to;
  final bool pending;
  final bool spouse;
}

class _TreeLayout {
  _TreeLayout._(this.nodes, this.edges, this.size);

  factory _TreeLayout.build(
    List<Person> persons,
    List<Relationship> rels, {
    bool rtl = false,
  }) {
    if (persons.isEmpty) return _TreeLayout._(const [], const [], Size.zero);
    final byId = {for (final p in persons) p.id: p};

    // Parents of each person (confirmed and pending kept separate).
    final parentsOf = <String, Set<String>>{};
    final spouseOf = <String, Set<String>>{};
    final pendingEdges = <(String, String, bool)>[]; // (a, b, isSpouse)
    for (final r in rels) {
      if (!byId.containsKey(r.personId) ||
          !byId.containsKey(r.relatedPersonId)) {
        continue;
      }
      switch (r.type) {
        case RelationshipType.parent:
          if (r.status == RelationshipStatus.confirmed) {
            parentsOf.putIfAbsent(r.personId, () => {}).add(r.relatedPersonId);
          } else {
            pendingEdges.add((r.relatedPersonId, r.personId, false));
          }
        case RelationshipType.child:
          if (r.status == RelationshipStatus.confirmed) {
            parentsOf.putIfAbsent(r.relatedPersonId, () => {}).add(r.personId);
          } else {
            pendingEdges.add((r.personId, r.relatedPersonId, false));
          }
        case RelationshipType.spouse:
          if (r.status == RelationshipStatus.confirmed) {
            spouseOf.putIfAbsent(r.personId, () => {}).add(r.relatedPersonId);
          } else {
            pendingEdges.add((r.personId, r.relatedPersonId, true));
          }
        case RelationshipType.sibling:
          break; // same generation; no edge drawn in this simple layout
      }
    }

    // Generation: longest path up from a root.
    final gen = <String, int>{};
    int generationOf(String id, [Set<String>? seen]) {
      final known = gen[id];
      if (known != null) return known;
      final trail = seen ?? <String>{};
      if (!trail.add(id)) return 0; // cycle guard
      final parents = parentsOf[id] ?? const <String>{};
      var g = 0;
      for (final parent in parents) {
        g = math.max(g, generationOf(parent, trail) + 1);
      }
      trail.remove(id);
      return gen[id] = g;
    }

    for (final p in persons) {
      generationOf(p.id);
    }

    // Group by generation; keep spouses adjacent within a row.
    final rows = <int, List<String>>{};
    for (final p in persons) {
      rows.putIfAbsent(gen[p.id] ?? 0, () => []).add(p.id);
    }
    final centers = <String, Offset>{};
    var maxRow = 0;
    for (final entry in rows.entries) {
      final ordered = _spousesAdjacent(entry.value, spouseOf);
      maxRow = math.max(maxRow, ordered.length);
      for (var i = 0; i < ordered.length; i++) {
        centers[ordered[i]] = Offset(
          _pad + nodeRadius + i * (_hGap + nodeRadius * 2),
          _pad + nodeRadius + entry.key * (_vGap + nodeRadius * 2),
        );
      }
    }

    final generations = (gen.values.fold<int>(0, math.max)) + 1;
    final size = Size(
      _pad * 2 + maxRow * (nodeRadius * 2 + _hGap),
      _pad * 2 + generations * (nodeRadius * 2 + _vGap),
    );
    // Right-to-left: mirror the coordinates, not the widgets, so names
    // and initials stay readable while the tree reads right to left.
    if (rtl) {
      centers.updateAll((_, c) => Offset(size.width - c.dx, c.dy));
    }

    final nodes = [
      for (final p in persons)
        _Node(person: p, center: centers[p.id]!, generation: gen[p.id] ?? 0),
    ];

    final edges = <_Edge>[];
    final drawnSpouses = <String>{};
    spouseOf.forEach((a, others) {
      for (final b in others) {
        final key = [a, b]..sort();
        if (drawnSpouses.add(key.join('|'))) {
          edges.add(_Edge(centers[a]!, centers[b]!, spouse: true));
        }
      }
    });
    parentsOf.forEach((child, parents) {
      for (final parent in parents) {
        edges.add(_Edge(centers[parent]!, centers[child]!));
      }
    });
    for (final (a, b, isSpouse) in pendingEdges) {
      edges.add(
        _Edge(centers[a]!, centers[b]!, pending: true, spouse: isSpouse),
      );
    }
    return _TreeLayout._(nodes, edges, size);
  }

  final List<_Node> nodes;
  final List<_Edge> edges;
  final Size size;

  static const nodeRadius = 30.0;
  static const labelWidth = 110.0;
  static const labelHeight = 18.0;
  static const _hGap = 110.0;
  static const _vGap = 130.0;
  static const _pad = 60.0;

  static List<String> _spousesAdjacent(
    List<String> ids,
    Map<String, Set<String>> spouseOf,
  ) {
    final placed = <String>{};
    final result = <String>[];
    for (final id in ids) {
      if (!placed.add(id)) continue;
      result.add(id);
      for (final spouse in spouseOf[id] ?? const <String>{}) {
        if (ids.contains(spouse) && placed.add(spouse)) {
          result.add(spouse);
        }
      }
    }
    return result;
  }
}

class _TreeNode extends StatelessWidget {
  const _TreeNode({required this.node, required this.progress, this.onTap});

  final _Node node;
  final double progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final linked = node.person.linkedUserId != null;
    final initial = node.person.fullName.isEmpty
        ? '?'
        : node.person.fullName.characters.first;
    return Opacity(
      opacity: progress.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.6 + 0.4 * progress,
        child: Semantics(
          button: onTap != null,
          label: node.person.fullName,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: linked ? scheme.primary : scheme.surface,
                border: Border.all(
                  color: linked ? scheme.primary : AppColors.inkSoft,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: linked ? scheme.onPrimary : AppColors.inkSoft,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The person's name under their node, so the tree reads without a legend.
class _TreeNodeLabel extends StatelessWidget {
  const _TreeNodeLabel({required this.node, required this.progress});

  final _Node node;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: progress.clamp(0.0, 1.0),
      child: ExcludeSemantics(
        child: Text(
          node.person.fullName,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ),
    );
  }
}

class _TreePainter extends CustomPainter {
  _TreePainter({
    required this.layout,
    required this.progress,
    required this.lineColor,
  });

  final _TreeLayout layout;
  final double progress;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final edge in layout.edges) {
      // Rope-like connectors: a gentle sag instead of a rigid straight
      // line, drawing in as the animation runs, oldest generation first.
      // Ends attach at the node's boundary, and steep downward edges
      // start under the name label so names stay unobstructed.
      final local = Curves.easeOut.transform(progress.clamp(0.0, 1.0));
      final a = _attach(edge.from, edge.to);
      final b = _attach(edge.to, edge.from);
      final path = _rope(a, b);
      final metric = path.computeMetrics().first;
      final shown = metric.length * local;
      if (shown <= 0) continue;
      if (edge.pending) {
        _dashed(canvas, paint, path, shown);
      } else {
        canvas.drawPath(metric.extractPath(0, shown), paint);
      }
    }
  }

  /// Where a connector leaves [from] on its way to [toward]: on the
  /// circle boundary for sideways/upward directions, and below the name
  /// label for steep downward ones so the rope never crosses the name.
  Offset _attach(Offset from, Offset toward) {
    final d = toward - from;
    if (d.distance == 0) return from;
    final dir = d / d.distance;
    if (dir.dy > 0.55) {
      const drop = _TreeLayout.nodeRadius + 6 + _TreeLayout.labelHeight + 6;
      final dx = (dir.dx / dir.dy * drop).clamp(
        -(_TreeLayout.labelWidth / 2 - 14),
        _TreeLayout.labelWidth / 2 - 14,
      );
      return Offset(from.dx + dx, from.dy + drop);
    }
    return from + dir * _TreeLayout.nodeRadius;
  }

  /// A quadratic curve with a slight downward sag, like a rope hung
  /// between the two people.
  Path _rope(Offset a, Offset b) {
    final mid = (a + b) / 2;
    final sag = math.max((b - a).distance * 0.07, 6).toDouble();
    return Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(mid.dx, mid.dy + sag, b.dx, b.dy);
  }

  void _dashed(Canvas canvas, Paint paint, Path path, double shown) {
    const dash = 8.0;
    const gap = 6.0;
    final metric = path.computeMetrics().first;
    var d = 0.0;
    while (d < shown) {
      final end = math.min(d + dash, shown);
      canvas.drawPath(metric.extractPath(d, end), paint);
      d = end + gap;
    }
  }

  @override
  bool shouldRepaint(_TreePainter old) =>
      old.progress != progress || old.layout != layout;
}
