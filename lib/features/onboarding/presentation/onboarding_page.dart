import 'dart:async';
import 'dart:math' as math;

import 'package:family_stories/core/analytics/analytics.dart';
import 'package:family_stories/core/router/app_routes.dart';
import 'package:family_stories/core/theme/app_colors.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/features/onboarding/data/onboarding.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The first-launch welcome (`/welcome`): a progressive start instead of a
/// slide carousel. You appear as the first node of your tree, optionally add
/// your parents, and watch the tree grow with each step. The names are kept
/// as a draft (onboarding.dart); the Family tab offers to add exactly these
/// people, and nothing is created before that confirmation.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _steps = 4;

  int _step = 0;
  final _name = TextEditingController();
  final _father = TextEditingController();
  final _mother = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _father.dispose();
    _mother.dispose();
    super.dispose();
  }

  OnboardingDraft get _draft => OnboardingDraft(
    name: _name.text,
    father: _father.text,
    mother: _mother.text,
  );

  void _finish({required bool skipped}) {
    unawaited(Analytics.capture('onboarding_completed', {'skipped': skipped}));
    unawaited(Onboarding.complete());
    unawaited(Onboarding.saveDraft(_draft));
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final last = _step == _steps - 1;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: AppButton.secondary(
                  key: const Key('onboarding_skip'),
                  label: l10n.onboardingSkip,
                  expand: false,
                  onPressed: () => _finish(skipped: true),
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                label: l10n.onboardingProgress(_step + 1, _steps),
                child: _StepDots(step: _step, count: _steps),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: _buildStep(context),
                  ),
                ),
              ),
              Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: AppButton.secondary(
                          key: const Key('onboarding_back'),
                          label: l10n.onboardingBack,
                          expand: false,
                          onPressed: () => setState(() => _step--),
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: AppButton.primary(
                      key: const Key('onboarding_next'),
                      label: last ? l10n.onboardingStart : l10n.onboardingNext,
                      onPressed: last
                          ? () => _finish(skipped: false)
                          : () => setState(() => _step++),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    final l10n = context.l10n;
    switch (_step) {
      case 0:
        return _StepBody(
          title: l10n.onboardingWelcomeTitle,
          body: l10n.onboardingWelcomeBody,
          tree: _SeedTree(draft: _draft, reveal: const _Reveal(you: true)),
        );
      case 1:
        return _StepBody(
          title: l10n.onboardingYouTitle,
          body: l10n.onboardingYouBody,
          tree: _SeedTree(draft: _draft, reveal: const _Reveal(you: true)),
          field: TextField(
            key: const Key('onboarding_name'),
            controller: _name,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: l10n.onboardingNameHint),
          ),
        );
      case 2:
        return _StepBody(
          title: l10n.onboardingParentsTitle,
          body: l10n.onboardingParentsBody,
          tree: _SeedTree(
            draft: _draft,
            reveal: const _Reveal(you: true, father: true, mother: true),
          ),
          field: Column(
            children: [
              TextField(
                key: const Key('onboarding_father'),
                controller: _father,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.onboardingFatherHint,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('onboarding_mother'),
                controller: _mother,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.onboardingMotherHint,
                ),
              ),
            ],
          ),
        );
      default:
        return _StepBody(
          title: l10n.onboardingReadyTitle,
          body: l10n.onboardingReadyBody,
          tree: _SeedTree(
            draft: _draft,
            reveal: const _Reveal(you: true, father: true, mother: true),
            animate: false,
          ),
        );
    }
  }
}

class _Reveal {
  const _Reveal({this.you = false, this.father = false, this.mother = false});
  final bool you;
  final bool father;
  final bool mother;
}

class _StepBody extends StatelessWidget {
  const _StepBody({
    required this.title,
    required this.body,
    required this.tree,
    this.field,
  });

  final String title;
  final String body;
  final Widget tree;
  final Widget? field;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(
          body,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        SizedBox(height: 220, child: tree),
        if (field != null) ...[const SizedBox(height: 8), field!],
      ],
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.step, required this.count});

  final int step;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == step ? scheme.primary : scheme.outlineVariant,
            ),
          ),
      ],
    );
  }
}

/// The growing tree sketch: you at the bottom, parents above, lines drawing
/// in as names appear. Decorative; the text fields carry the real values.
class _SeedTree extends StatefulWidget {
  const _SeedTree({
    required this.draft,
    required this.reveal,
    this.animate = true,
  });

  final OnboardingDraft draft;
  final _Reveal reveal;
  final bool animate;

  @override
  State<_SeedTree> createState() => _SeedTreeState();
}

class _SeedTreeState extends State<_SeedTree>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.animate ||
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
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
    final l10n = context.l10n;
    final you = widget.draft.name.trim().isEmpty
        ? l10n.onboardingYouFallback
        : widget.draft.name.trim();
    final father = widget.draft.father.trim().isEmpty
        ? l10n.onboardingFatherFallback
        : widget.draft.father.trim();
    final mother = widget.draft.mother.trim().isEmpty
        ? l10n.onboardingMotherFallback
        : widget.draft.mother.trim();
    return Semantics(
      label: l10n.onboardingTreeLabel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _SeedTreePainter(
            you: widget.reveal.you ? you : null,
            father: widget.reveal.father ? father : null,
            mother: widget.reveal.mother ? mother : null,
            progress: _controller.value,
            textDirection: Directionality.of(context),
            color: AppColors.primary,
            lineColor: AppColors.inkSoft,
            labelStyle: Theme.of(context).textTheme.labelMedium!,
          ),
        ),
      ),
    );
  }
}

class _SeedTreePainter extends CustomPainter {
  _SeedTreePainter({
    required this.you,
    required this.father,
    required this.mother,
    required this.progress,
    required this.textDirection,
    required this.color,
    required this.lineColor,
    required this.labelStyle,
  });

  final String? you;
  final String? father;
  final String? mother;
  final double progress;
  final TextDirection textDirection;
  final Color color;
  final Color lineColor;
  final TextStyle labelStyle;

  static const _radius = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final youC = Offset(size.width / 2, size.height - _radius - 24);
    final fatherC = Offset(size.width / 4, _radius + 8);
    final motherC = Offset(size.width * 3 / 4, _radius + 8);
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5;

    // Nodes spring in first, then the lines draw towards the parents.
    final nodeT = _interval(progress, 0, 0.5);
    final lineT = _interval(progress, 0.4, 1);

    if (father != null && lineT > 0) {
      _line(canvas, youC, fatherC, lineT, linePaint);
    }
    if (mother != null && lineT > 0) {
      _line(canvas, youC, motherC, lineT, linePaint);
    }
    if (you != null) {
      _node(canvas, youC, you!, nodeT, filled: true);
    }
    if (father != null) {
      _node(canvas, fatherC, father!, nodeT, filled: false);
    }
    if (mother != null) {
      _node(canvas, motherC, mother!, nodeT, filled: false);
    }
  }

  double _interval(double t, double start, double end) =>
      ((t - start) / (end - start)).clamp(0, 1).toDouble();

  void _line(Canvas canvas, Offset a, Offset b, double t, Paint paint) {
    // Rope-like: a slight downward sag, drawing in from a to b. Ends
    // attach at the circle boundary; steep downward ends start under
    // the name label so the rope never crosses the name.
    final start = _attach(a, b);
    final end = _attach(b, a);
    final mid = (start + end) / 2;
    final sag = math.max((end - start).distance * 0.07, 5).toDouble();
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(mid.dx, mid.dy + sag, end.dx, end.dy);
    final metric = path.computeMetrics().first;
    canvas.drawPath(metric.extractPath(0, metric.length * t), paint);
  }

  Offset _attach(Offset from, Offset toward) {
    final d = toward - from;
    if (d.distance == 0) return from;
    final dir = d / d.distance;
    if (dir.dy > 0.55) {
      const drop = _radius + 26;
      final dx = (dir.dx / dir.dy * drop).clamp(-46.0, 46.0);
      return Offset(from.dx + dx, from.dy + drop);
    }
    return from + dir * _radius;
  }

  void _node(
    Canvas canvas,
    Offset c,
    String label,
    double t, {
    required bool filled,
  }) {
    final scale = Curves.easeOutBack.transform(t);
    if (scale <= 0) return;
    final r = _radius * math.min(scale, 1.2);
    final paint = Paint()..color = color;
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    if (filled) {
      canvas.drawCircle(c, r, paint);
    } else {
      canvas.drawCircle(c, r, ring);
    }
    final initial = label.characters.first;
    _text(
      canvas,
      c,
      initial,
      labelStyle.copyWith(
        color: filled ? AppColors.surface : color,
        fontWeight: FontWeight.w600,
      ),
    );
    _text(
      canvas,
      c + const Offset(0, _radius + 14),
      label,
      labelStyle.copyWith(color: lineColor),
    );
  }

  void _text(Canvas canvas, Offset c, String s, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: textDirection,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_SeedTreePainter old) =>
      old.you != you ||
      old.father != father ||
      old.mother != mother ||
      old.progress != progress ||
      old.textDirection != textDirection ||
      old.color != color ||
      old.lineColor != lineColor;
}
