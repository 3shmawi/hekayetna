import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/core/theme/app_theme.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Who can listen (Design System card): three large options and, under the
/// choice, one plain sentence that says exactly who will hear it. Sharing
/// is explicit snapshots, never dynamic whole-family access.
class VisibilityPicker extends StatelessWidget {
  const VisibilityPicker({
    required this.value,
    required this.onChanged,
    required this.consequenceText,
    this.filled,
    super.key,
  });

  final StoryVisibility value;
  final ValueChanged<StoryVisibility> onChanged;

  /// e.g. "3 people can hear this: Mama, Omar, Nour."
  final String consequenceText;

  /// Optional filled-selection look (auth/SaveStory theme): colors for the
  /// selected card and the card text. Null keeps the app-wide look.
  final VisibilityFill? filled;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final hk = context.hk;
    final options = <(StoryVisibility, String)>[
      (StoryVisibility.onlyMe, s.visibilityOnlyMe),
      (StoryVisibility.selectedPeople, s.visibilitySelectedPeople),
      (StoryVisibility.wholeFamily, s.visibilityWholeFamily),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (option, label) in options) ...[
          _VisibilityOption(
            label: label,
            selected: value == option,
            fill: filled,
            onTap: () => onChanged(option),
          ),
          SizedBox(height: AppDimens.sm),
        ],
        SizedBox(height: AppDimens.sm),
        Text(
          consequenceText,
          style: AppTextStyles.body.copyWith(color: hk.inkSoft),
        ),
      ],
    );
  }
}

enum StoryVisibility { onlyMe, selectedPeople, wholeFamily }

/// Colors for the filled selected card.
class VisibilityFill {
  const VisibilityFill({
    required this.selected,
    required this.onSelected,
    required this.idle,
    required this.onIdle,
    required this.serif,
  });
  final Color selected;
  final Color onSelected;
  final Color idle;
  final Color onIdle;
  final String serif;
}

class _VisibilityOption extends StatelessWidget {
  const _VisibilityOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.fill,
  });

  final VisibilityFill? fill;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          child: Container(
            constraints: BoxConstraints(minHeight: AppDimens.targetMin),
            padding: EdgeInsets.symmetric(
              horizontal: AppDimens.lg,
              vertical: AppDimens.md,
            ),
            decoration: BoxDecoration(
              color: fill != null
                  ? (selected ? fill!.selected : fill!.idle)
                  : (selected ? scheme.primaryContainer : scheme.surface),
              border: fill != null
                  ? null
                  : Border.all(
                      color: selected ? scheme.primary : scheme.outlineVariant,
                      width: selected ? 2 : 1,
                    ),
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            alignment: AlignmentDirectional.centerStart,
            child: ExcludeSemantics(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: fill == null
                    ? AppTextStyles.label
                    : AppTextStyles.label.copyWith(
                        color: selected ? fill!.onSelected : fill!.onIdle,
                        fontFamily: selected ? fill!.serif : null,
                        fontFamilyFallback: const ['Cairo'],
                        fontWeight: selected ? FontWeight.w600 : null,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
