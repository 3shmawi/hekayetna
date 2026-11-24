import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// A section's small uppercase label ("RECENTLY ADDED"). Arabic has no
/// uppercase, so it renders as-is at 15px.
class AppSectionLabel extends StatelessWidget {
  const AppSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Text(
      isArabic ? text : text.toUpperCase(),
      style: AppTextStyles.caption.copyWith(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: isArabic ? null : 0.8,
      ),
    );
  }
}
