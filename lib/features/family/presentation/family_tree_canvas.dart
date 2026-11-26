import 'dart:math' as math;

import 'package:family_stories/core/adaptive/adaptive.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/features/family/data/models.dart';
import 'package:family_stories/features/family/domain/family_graph.dart';
import 'package:family_stories/features/family/domain/family_layout.dart';
import 'package:family_stories/features/family/domain/kinship.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Zoom limits from spec 05.
const double kTreeMinScale = 0.08;
const double kTreeMaxScale = 1.8;

/// Below this zoom the rope pills and relation lines hide (spec 05).
const double kTreeLabelsMinScale = 0.75;

enum TreeZoomVia { pinch, button, fit, center }

/// Lets the page drive the canvas (search, fit, center) without owning its
/// internals.
class FamilyTreeController {
  _FamilyTreeCanvasState? _state;

  void focusOn(String personId) => _state?._focusOn(personId);
  void fit() => _state?._fit();
  void centerOnMe() => _state?._centerOnMe();
  void zoomBy(double factor) => _state?._zoomButton(factor);

  /// Current zoom (1.0 = 100%), for tests and the zoom chip.
  double get scale => _state?._scale ?? 1;
}

/// The pan/zoom canvas: ropes under, nodes over, built only for what is
/// on screen. Pure layout lives in `family_layout.dart`.
class FamilyTreeCanvas extends StatefulWidget {
  const FamilyTreeCanvas({
    required this.graph,
    required this.onTapPerson,
    this.onLongPressPerson,
    this.selectedId,
    this.controller,
    this.onZoomed,
    super.key,
  });

  final FamilyGraph graph;
  final ValueChanged<String> onTapPerson;
  final ValueChanged<String>? onLongPressPerson;

  /// When set, the ropes on the path between this person and "me" are
  /// drawn at full opacity and the rest dimmed to 30%.
  final String? selectedId;
  final FamilyTreeController? controller;
  final ValueChanged<TreeZoomVia>? onZoomed;

  @override
  State<FamilyTreeCanvas> createState() => _FamilyTreeCanvasState();
}

class _FamilyTreeCanvasState extends State<FamilyTreeCanvas> {
  final _tc = TransformationController();
  Size _viewport = Size.zero;
  bool _placed = false;
  FamilyLayout? _layout;
  bool _layoutRtl = false;
  FamilyGraph? _layoutGraph;

  double get _scale => _tc.value.entry(0, 0);

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _tc.addListener(_onTransform);
  }

  @override
  void didUpdateWidget(FamilyTreeCanvas old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?._state = null;
      widget.controller?._state = this;
    }
  }

  @override
  void dispose() {
    widget.controller?._state = null;
    _tc
      ..removeListener(_onTransform)
      ..dispose();
    super.dispose();
  }

  void _onTransform() => setState(() {});

  FamilyLayout _ensureLayout(bool rtl) {
    if (_layout == null || _layoutRtl != rtl || _layoutGraph != widget.graph) {
      final base = layoutFamily(widget.graph);
      _layout = rtl ? base.mirrored() : base;
      _layoutRtl = rtl;
      _layoutGraph = widget.graph;
      _placed = false;
    }
    return _layout!;
  }

  Rect _visibleScene() {
    if (_viewport.isEmpty) return Rect.zero;
    final inv = Matrix4.copy(_tc.value)..invert();
    final tl = MatrixUtils.transformPoint(inv, Offset.zero);
    final br = MatrixUtils.transformPoint(
      inv,
      Offset(_viewport.width, _viewport.height),
    );
    return Rect.fromPoints(tl, br);
  }

  void _setMatrix(double scale, Offset sceneAt, Offset viewportAt) {
    final s = scale.clamp(kTreeMinScale, kTreeMaxScale);
    _tc.value = Matrix4.identity()
      ..translateByDouble(
        viewportAt.dx - sceneAt.dx * s,
        viewportAt.dy - sceneAt.dy * s,
        0,
        1,
      )
      ..scaleByDouble(s, s, 1, 1);
  }

  void _zoomAround(double factor, Offset viewportAt) {
    final scene = _tc.toScene(viewportAt);
    _setMatrix(_scale * factor, scene, viewportAt);
  }

  void _zoomButton(double factor) {
    _zoomAround(factor, _viewport.center(Offset.zero));
    widget.onZoomed?.call(TreeZoomVia.button);
  }

  void _fit() {
    final l = _layout;
    if (l == null || _viewport.isEmpty) return;
    final s = math.min(
      _viewport.width / l.bounds.width,
      _viewport.height / l.bounds.height,
    );
    _setMatrix(s > 1 ? 1 : s, l.bounds.center, _viewport.center(Offset.zero));
    widget.onZoomed?.call(TreeZoomVia.fit);
  }

  void _centerOnMe({bool notify = true}) {
    final l = _layout;
    if (l == null || _viewport.isEmpty) return;
    final me = widget.graph.meId;
    final at = me != null && l.nodes[me] != null
        ? l.nodes[me]!.center
        : l.bounds.center;
    _setMatrix(1, at, _viewport.center(Offset.zero));
    if (notify) widget.onZoomed?.call(TreeZoomVia.center);
  }

  void _focusOn(String id) {
    final n = _layout?.nodes[id];
    if (n == null || _viewport.isEmpty) return;
    _setMatrix(1.2, n.center, _viewport.center(Offset.zero));
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final layout = _ensureLayout(rtl);
    // The controls and the legend sit beside and below the canvas, never
    // on top of it, so no person can be hidden under them.
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: _viewer(layout)),
                    // Artboard: the zoom % chip sits at the start, top.
                    PositionedDirectional(
                      start: AppDimens.md,
                      top: AppDimens.sm,
                      child: _ZoomChip(zoom: _scale),
                    ),
                  ],
                ),
              ),
              _Controls(
                zoom: _scale,
                onZoomIn: () => _zoomButton(1.25),
                onZoomOut: () => _zoomButton(0.8),
                onFit: _fit,
                onCenter: _centerOnMe,
              ),
            ],
          ),
        ),
        const _Legend(),
      ],
    );
  }

  Widget _viewer(FamilyLayout layout) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        if (!_placed && !_viewport.isEmpty) {
          _placed = true;
          // Open centred on "me" at 100%.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _centerOnMe(notify: false);
          });
        }
        return ClipRect(
          child: InteractiveViewer(
            transformationController: _tc,
            constrained: false,
            minScale: kTreeMinScale,
            maxScale: kTreeMaxScale,
            boundaryMargin: const EdgeInsets.all(200),
            child: _Scene(
              layout: layout,
              graph: widget.graph,
              visible: _visibleScene().inflate(160),
              zoom: _scale,
              selectedId: widget.selectedId,
              onTapPerson: widget.onTapPerson,
              onLongPressPerson: widget.onLongPressPerson,
              // Double tap lives on the background only, so a tap on
              // a person is never delayed waiting for a second tap.
              onDoubleTapAt: (scenePoint) {
                _zoomAround(
                  1.5,
                  MatrixUtils.transformPoint(_tc.value, scenePoint),
                );
                widget.onZoomed?.call(TreeZoomVia.pinch);
              },
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _Scene extends StatelessWidget {
  const _Scene({
    required this.layout,
    required this.graph,
    required this.visible,
    required this.zoom,
    required this.selectedId,
    required this.onTapPerson,
    required this.onLongPressPerson,
    required this.onDoubleTapAt,
  });

  final ValueChanged<Offset> onDoubleTapAt;
  final FamilyLayout layout;
  final FamilyGraph graph;
  final Rect visible;
  final double zoom;
  final String? selectedId;
  final ValueChanged<String> onTapPerson;
  final ValueChanged<String>? onLongPressPerson;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final me = graph.meId;
    Set<int>? lit;
    if (selectedId != null && me != null) {
      final path = graph.pathBetween(selectedId!, me);
      if (path != null) lit = ropesOnPath(layout, path);
    }
    final showLabels = zoom >= kTreeLabelsMinScale;
    final nodes = [
      for (final n in layout.nodes.values)
        if (n.bounds.overlaps(visible)) n,
    ];
    return SizedBox(
      width: layout.bounds.width,
      height: layout.bounds.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: _BackgroundTap(
              onDoubleTapAt: onDoubleTapAt,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: TreePainter(
                    layout: layout,
                    visible: visible,
                    litRopes: lit,
                    confirmed: scheme.primary,
                    pending: scheme.onSurfaceVariant,
                    dot: context.hk.line,
                  ),
                ),
              ),
            ),
          ),
          if (layout.unconnected.isNotEmpty)
            Positioned(
              left: TreeMetrics.margin,
              top: layout.unconnectedTop,
              child: Semantics(
                header: true,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: l10n.treeNotConnected,
                        style: AppTextStyles.label,
                      ),
                      TextSpan(
                        text: '  ${l10n.treeNotConnectedHint}',
                        style: AppTextStyles.caption.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          for (final p in layout.pills)
            if (showLabels && _near(p.at)) _PillWidget(pill: p, graph: graph),
          for (final n in nodes)
            Positioned.fromRect(
              rect: n.bounds,
              child: _TreeNode(
                node: n,
                graph: graph,
                showRelation: showLabels,
                onTap: () => onTapPerson(n.id),
                onLongPress: onLongPressPerson == null
                    ? null
                    : () => onLongPressPerson!(n.id),
              ),
            ),
        ],
      ),
    );
  }

  bool _near(Offset p) => visible.contains(p);
}

class _BackgroundTap extends StatelessWidget {
  const _BackgroundTap({required this.onDoubleTapAt, required this.child});

  final ValueChanged<Offset> onDoubleTapAt;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    var at = Offset.zero;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: (d) => at = d.localPosition,
      onDoubleTap: () => onDoubleTapAt(at),
      child: child,
    );
  }
}

class _PillWidget extends StatelessWidget {
  const _PillWidget({required this.pill, required this.graph});

  final RopePill pill;
  final FamilyGraph graph;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = switch (pill.kind) {
      PillKind.couple => pill.pending ? l10n.treePendingPill : l10n.treeMarried,
      PillKind.child => l10n.kinshipLabel(
        switch (graph.persons[pill.personId]?.gender) {
          PersonGender.female => 'daughter',
          PersonGender.male => 'son',
          null => 'child',
        },
      ),
    };
    // Artboard and spec 05: rope pills are lowercase ("daughter", "married").
    // Arabic has no case, so this leaves it unchanged.
    final shown = text.toLowerCase();
    return Positioned(
      left: pill.at.dx - 44,
      top: pill.at.dy - 11,
      width: 88,
      height: 22,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: pill.pending ? scheme.onSurfaceVariant : context.hk.line,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(
              shown,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.tabLabel.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TreeNode extends StatelessWidget {
  const _TreeNode({
    required this.node,
    required this.graph,
    required this.showRelation,
    required this.onTap,
    required this.onLongPress,
  });

  final NodeLayout node;
  final FamilyGraph graph;
  final bool showRelation;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final person = graph.persons[node.id]!;
    final count = graph.storyCounts[node.id] ?? 0;
    final isMe = graph.meId == node.id;
    final me = graph.meId;
    final relation = me == null
        ? null
        : l10n.kinshipLabel(kinshipKey(graph, me, node.id));
    final semantics = relation == null
        ? l10n.treeNodeSemanticsNoRelation(person.fullName, count)
        : l10n.treeNodeSemantics(person.fullName, relation, count);
    return Semantics(
      container: true,
      button: true,
      label: semantics,
      onTap: onTap,
      onLongPress: onLongPress,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onLongPress: onLongPress,
          child: Column(
            children: [
              SizedBox(
                width: TreeMetrics.avatar + 12,
                height: TreeMetrics.avatar,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size.square(TreeMetrics.avatar),
                      painter: _RingPainter(
                        color: scheme.primary,
                        hasStories: count > 0,
                        isMe: isMe,
                      ),
                      child: Container(
                        width: TreeMetrics.avatar,
                        height: TreeMetrics.avatar,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.primaryContainer,
                        ),
                        child: Text(
                          person.fullName.characters.first,
                          style: AppTextStyles.title.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    if (count > 0)
                      PositionedDirectional(
                        end: 0,
                        top: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(5),
                            child: Text(
                              '$count',
                              style: AppTextStyles.countBadge.copyWith(
                                color: scheme.onPrimary,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: TreeMetrics.labelGap),
              // The tree is fixed geometry that the user zooms: a node's label
              // keeps its drawn size instead of growing with the system text
              // scale and overflowing its reserved height.
              MediaQuery.withNoTextScaling(
                child: SizedBox(
                  height: TreeMetrics.labelHeight,
                  child: Column(
                    children: [
                      Text(
                        person.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.label,
                      ),
                      if (showRelation && relation != null)
                        Text(
                          relation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.color,
    required this.hasStories,
    required this.isMe,
  });

  final Color color;
  final bool hasStories;
  final bool isMe;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    if (isMe) {
      canvas.drawCircle(
        c,
        r + 7,
        Paint()..color = color.withValues(alpha: 0.18),
      );
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isMe ? 5 : 3
      ..color = color;
    if (hasStories) {
      canvas.drawCircle(c, r, stroke);
    } else {
      stroke.color = color.withValues(alpha: 0.7);
      _dashedCircle(canvas, c, r, stroke);
    }
  }

  void _dashedCircle(Canvas canvas, Offset c, double r, Paint paint) {
    const dashes = 18;
    for (var i = 0; i < dashes; i++) {
      final start = i * 2 * math.pi / dashes;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start,
        math.pi / dashes,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.color != color || old.hasStories != hasStories || old.isMe != isMe;
}

/// Dotted background and ropes, painted under the nodes.
class TreePainter extends CustomPainter {
  const TreePainter({
    required this.layout,
    required this.visible,
    required this.litRopes,
    required this.confirmed,
    required this.pending,
    required this.dot,
  });

  final FamilyLayout layout;
  final Rect visible;

  /// Rope indexes on the selected path, or null when nothing is selected.
  final Set<int>? litRopes;
  final Color confirmed;
  final Color pending;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    final area = visible.intersect(Offset.zero & size);
    if (!area.isEmpty) {
      final dotPaint = Paint()..color = dot;
      const step = 28.0;
      for (
        var x = (area.left / step).floor() * step;
        x <= area.right;
        x += step
      ) {
        for (
          var y = (area.top / step).floor() * step;
          y <= area.bottom;
          y += step
        ) {
          canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
        }
      }
    }
    for (var i = 0; i < layout.ropes.length; i++) {
      final rope = layout.ropes[i];
      final bounds = _boundsOf(rope.points).inflate(4);
      if (!bounds.overlaps(visible)) continue;
      final dim = litRopes != null && !litRopes!.contains(i);
      final base = rope.pending ? pending : confirmed;
      final alpha = litRopes == null
          ? (rope.pending ? 1.0 : 0.7)
          : (dim ? 0.3 : 1.0);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3
        ..color = base.withValues(alpha: alpha);
      final path = roundedPath(rope.points, TreeMetrics.cornerRadius);
      canvas.drawPath(rope.pending ? _dashed(path) : path, paint);
    }
  }

  static Rect _boundsOf(List<Offset> pts) {
    var r = Rect.fromPoints(pts.first, pts.first);
    for (final p in pts) {
      r = r.expandToInclude(Rect.fromPoints(p, p));
    }
    return r;
  }

  Path _dashed(Path source) {
    final out = Path();
    for (final m in source.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        out.addPath(m.extractPath(d, math.min(d + 8, m.length)), Offset.zero);
        d += 14;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(TreePainter old) =>
      old.layout != layout ||
      old.visible != visible ||
      old.litRopes != litRopes ||
      old.confirmed != confirmed;
}

/// An orthogonal polyline with rounded corners of radius up to [radius].
Path roundedPath(List<Offset> pts, double radius) {
  final path = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (var i = 1; i < pts.length - 1; i++) {
    final prev = pts[i - 1];
    final cur = pts[i];
    final next = pts[i + 1];
    final r = math.min(
      radius,
      math.min((cur - prev).distance, (next - cur).distance) / 2,
    );
    final a = cur + (prev - cur) / (prev - cur).distance * r;
    final b = cur + (next - cur) / (next - cur).distance * r;
    path
      ..lineTo(a.dx, a.dy)
      ..quadraticBezierTo(cur.dx, cur.dy, b.dx, b.dy);
  }
  path.lineTo(pts.last.dx, pts.last.dy);
  return path;
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.zoom,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
    required this.onCenter,
  });

  final double zoom;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;
  final VoidCallback onCenter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    Widget button(IconData icon, String tip, VoidCallback onTap) => IconButton(
      tooltip: tip,
      style: IconButton.styleFrom(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outlineVariant),
        shape: const CircleBorder(),
      ),
      constraints: BoxConstraints.tightFor(
        width: AppDimens.targetMin,
        height: AppDimens.targetMin,
      ),
      onPressed: onTap,
      icon: Icon(icon),
    );
    return SizedBox(
      width: AppDimens.targetMin + AppDimens.md * 2,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppDimens.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            button(AdaptiveIcons.zoomIn(context), l10n.treeZoomIn, onZoomIn),
            SizedBox(height: AppDimens.sm),
            button(AdaptiveIcons.zoomOut(context), l10n.treeZoomOut, onZoomOut),
            SizedBox(height: AppDimens.sm),
            button(AdaptiveIcons.fitAll(context), l10n.treeFit, onFit),
            SizedBox(height: AppDimens.sm),
            button(
              AdaptiveIcons.centerMe(context),
              l10n.treeCenterMe,
              onCenter,
            ),
            SizedBox(height: AppDimens.sm),
          ],
        ),
      ),
    );
  }
}

class _ZoomChip extends StatelessWidget {
  const _ZoomChip({required this.zoom});

  final double zoom;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          context.l10n.treeZoomPercent((zoom * 100).round()),
          style: AppTextStyles.tabLabel,
          softWrap: false,
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    Widget entry(Widget mark, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 6),
        Text(text, style: AppTextStyles.tabLabel),
      ],
    );
    return Padding(
      padding: EdgeInsets.all(AppDimens.md),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                entry(
                  CustomPaint(
                    size: const Size.square(14),
                    painter: _RingPainter(
                      color: scheme.primary,
                      hasStories: true,
                      isMe: false,
                    ),
                  ),
                  l10n.treeLegendStories,
                ),
                entry(
                  CustomPaint(
                    size: const Size.square(14),
                    painter: _RingPainter(
                      color: scheme.primary,
                      hasStories: false,
                      isMe: false,
                    ),
                  ),
                  l10n.treeLegendNone,
                ),
                entry(
                  SizedBox(
                    width: 18,
                    child: CustomPaint(
                      size: const Size(18, 2),
                      painter: _DotsSample(scheme.onSurfaceVariant),
                    ),
                  ),
                  l10n.treeLegendPending,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three dots, as the artboard legend draws "not confirmed".
class _DotsSample extends CustomPainter {
  const _DotsSample(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    for (final x in const [2.0, 9.0, 16.0]) {
      canvas.drawCircle(Offset(x, 1), 1.5, p);
    }
  }

  @override
  bool shouldRepaint(_DotsSample old) => old.color != color;
}
