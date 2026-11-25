import 'dart:async';
import 'dart:math' as math;

import 'package:family_stories/core/analytics/analytics.dart';
import 'package:family_stories/core/router/app_routes.dart';
import 'package:family_stories/core/theme/app_colors.dart';
import 'package:family_stories/core/ui/app_ui.dart';
import 'package:family_stories/core/ui/language_switch.dart';
import 'package:family_stories/features/onboarding/data/onboarding.dart';
import 'package:family_stories/features/settings/presentation/settings_controller.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The first-launch welcome (`/welcome`): a progressive start instead of a
/// slide carousel. You appear as the first node of your tree, optionally add
/// your parents, and watch the tree grow with each step. The names are kept
/// as a draft (onboarding.dart); the Family tab offers to add exactly these
/// people, and nothing is created before that confirmation.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
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
    if (_step == 0) {
      return _WelcomeStep(
        steps: _steps,
        onLocaleChanged: ref
            .read(settingsControllerProvider.notifier)
            .setLocale,
        onStart: () => setState(() => _step = 1),
        onInvite: () => context.go(AppRoutes.join),
      );
    }
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

/// The first screen, as drawn in the design file ("Welcome"): a green
/// illustration panel, the page marker, the promise, and two ways in. The
/// illustration is decorative and is not mirrored in Arabic.
class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({
    required this.steps,
    required this.onLocaleChanged,
    required this.onStart,
    required this.onInvite,
  });

  final int steps;
  final ValueChanged<Locale> onLocaleChanged;
  final VoidCallback onStart;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final height = MediaQuery.sizeOf(context).height;
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: math.min(height * 0.42, 360),
            child: const ExcludeSemantics(child: _WelcomeHero()),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: LanguageSwitch(
                        key: const Key('onboarding_language'),
                        onChanged: onLocaleChanged,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      label: l10n.onboardingProgress(1, steps),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _StepPill(step: 0, count: steps),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.onboardingHeroTitle,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.onboardingHeroBody,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    AppButton.primary(
                      key: const Key('onboarding_next'),
                      label: l10n.onboardingStart,
                      wrap: true,
                      onPressed: onStart,
                    ),
                    const SizedBox(height: 12),
                    AppButton.secondary(
                      key: const Key('onboarding_have_invite'),
                      label: l10n.onboardingHaveInvite,
                      wrap: true,
                      onPressed: onInvite,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The artboard's page marker: the current page is a short bar, the rest
/// are dots.
class _StepPill extends StatelessWidget {
  const _StepPill({required this.step, required this.count});

  final int step;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: i == step ? 20 : 6,
            height: 6,
            margin: const EdgeInsetsDirectional.only(end: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: i == step ? scheme.primary : scheme.outlineVariant,
            ),
          ),
      ],
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero();

  // Fractions of the panel: centre x, centre y, turn (radians).
  static const _sticks = <(double, double, double)>[
    (0.13, 0.30, -0.75),
    (0.31, 0.22, 0.6),
    (0.81, 0.25, -0.75),
    (0.67, 0.55, 0.6),
    (0.20, 0.68, 0.6),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: AppColors.olive,
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final h = c.maxHeight;
            final unit = math.min(w, h * 1.0);
            final stickW = unit * 0.045;
            final stickH = unit * 0.15;
            final r = unit * 0.17;
            return Stack(
              children: [
                for (final (x, y, a) in _sticks)
                  Positioned(
                    left: w * x - stickW / 2,
                    top: h * y - stickH / 2,
                    child: Transform.rotate(
                      angle: a,
                      child: Container(
                        width: stickW,
                        height: stickH,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(stickW),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: w * 0.5 - r,
                  top: h * 0.76 - r,
                  child: Container(
                    width: r * 2,
                    height: r * 2,
                    decoration: const BoxDecoration(
                      color: AppColors.terracotta,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mic_none_rounded,
                      color: Colors.white,
                      size: r * 1.1,
                    ),
                  ),
                ),
                Positioned(
                  left: w * 0.82 - unit * 0.06,
                  top: h * 0.76 - unit * 0.06,
                  child: Container(
                    width: unit * 0.12,
                    height: unit * 0.12,
                    decoration: const BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
