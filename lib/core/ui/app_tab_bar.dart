import 'dart:ui' show ImageFilter;

import 'package:family_stories/core/adaptive/adaptive.dart';
import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The three main tabs (artboard Main): Stories · [Record] · Family. The
/// centre item is a 64px terracotta circle with a mic icon inside a 4px
/// sand ring (72px total). It carries the design system's `shadow-record`
/// and floats with its bottom flush with the bar's content bottom, so its
/// top crosses the bar's hairline, exactly as drawn on artboard Main. The
/// bar is frosted (blur 18, surface at 82%) with a hairline top border,
/// safe-area aware. Labels are 12/16 w600.
class AppTabBar extends StatelessWidget {
  const AppTabBar({required this.currentIndex, required this.onTap, super.key});

  final int currentIndex;

  /// Tapping the current tab pops to its root (the caller keeps goBranch's
  /// `initialLocation` behaviour).
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final items = [
      (AdaptiveIcons.stories(context), s.stories, s.stories),
      (AdaptiveIcons.record(context), s.record, s.recordAStory),
      (AdaptiveIcons.family(context), s.family, s.family),
    ];
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: AppDimens.glassBlur,
              sigmaY: AppDimens.glassBlur,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: AppDimens.glassOpacity),
                border: Border(
                  top: BorderSide(color: scheme.outlineVariant, width: 0.5),
                ),
              ),
              padding: EdgeInsets.only(bottom: bottomPad),
              child: SizedBox(
                height: 64,
                child: Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: i == 1
                            // The centre cell stays empty: the record circle
                            // floats above it (and above the hairline).
                            ? const SizedBox()
                            : _Tab(
                                icon: items[i].$1,
                                label: items[i].$2,
                                semanticsLabel: items[i].$3,
                                selected: currentIndex == i,
                                onTap: () => onTap(i),
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomPad,
          child: Center(
            child: _RecordTab(
              icon: items[1].$1,
              semanticsLabel: items[1].$3,
              onTap: () => onTap(1),
            ),
          ),
        ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.semanticsLabel,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String semanticsLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: AppDimens.iconMd, color: color),
              SizedBox(height: AppDimens.xs),
              ExcludeSemantics(
                child: Text(
                  label,
                  maxLines: 1,
                  style: AppTextStyles.tabLabel.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordTab extends StatelessWidget {
  const _RecordTab({
    required this.icon,
    required this.semanticsLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hk = context.hk;
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 72,
          height: 72,
          // The 4px sand ring sits outside the 64px terracotta circle, as
          // drawn on artboard Main; `shadow-record` goes under the button.
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hk.sand,
            boxShadow: AppTheme.recordShadow,
          ),
          child: Container(
            decoration: BoxDecoration(shape: BoxShape.circle, color: hk.record),
            child: Icon(icon, size: 28, color: hk.onRecord),
          ),
        ),
      ),
    );
  }
}
