import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// English / Arabic choice for screens shown before the user has signed in
/// (welcome, sign-in). Each label is written in its own language.
class LanguageSwitch extends StatelessWidget {
  const LanguageSwitch({required this.onChanged, super.key});

  final ValueChanged<Locale> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = Localizations.localeOf(context).languageCode;
    return Wrap(
      spacing: AppDimens.sm,
      runSpacing: AppDimens.sm,
      children: [
        for (final (label, locale) in [
          (l10n.languageEnglish, const Locale('en')),
          (l10n.languageArabic, const Locale('ar')),
        ])
          ChoiceChip(
            label: Text(label),
            selected: current == locale.languageCode,
            onSelected: (_) => onChanged(locale),
          ),
      ],
    );
  }
}
