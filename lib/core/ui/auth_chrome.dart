import 'package:family_stories/core/theme/app_dimens.dart';
import 'package:family_stories/core/theme/app_fonts.dart';
import 'package:family_stories/core/theme/app_text_styles.dart';
import 'package:family_stories/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Colours of the auth screens, from the approved "Warm Heritage Archive"
/// direction (Stitch project design tokens), light and a dark counterpart
/// derived here (Stitch's dark variants are not generated yet).
// ignore: use_enums
class AuthPalette {
  const AuthPalette._({
    required this.background,
    required this.field,
    required this.fieldRaised,
    required this.track,
    required this.selected,
    required this.onSelected,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.secondaryFill,
    required this.text,
    required this.textSoft,
    required this.placeholder,
  });

  final Color background;
  final Color field;
  final Color fieldRaised;
  final Color track;
  final Color selected;
  final Color onSelected;
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color secondaryFill;
  final Color text;
  final Color textSoft;
  final Color placeholder;

  static const light = AuthPalette._(
    background: Color(0xFFF6FBF4),
    field: Color(0xFFEBEFE8),
    fieldRaised: Color(0xFFFFFFFF),
    track: Color(0xFFEBEFE8),
    selected: Color(0xFFFFFFFF),
    onSelected: Color(0xFF181D19),
    primary: Color(0xFF243828),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF775A19),
    secondaryFill: Color(0xFFE5E9E3),
    text: Color(0xFF181D19),
    textSoft: Color(0xFF434842),
    placeholder: Color(0xFF5E635D),
  );

  static const dark = AuthPalette._(
    background: Color(0xFF131A15),
    field: Color(0xFF222A24),
    fieldRaised: Color(0xFF2A332C),
    track: Color(0xFF222A24),
    selected: Color(0xFF3A483C),
    onSelected: Color(0xFFEDF2EB),
    primary: Color(0xFFB5CDB6),
    onPrimary: Color(0xFF0F2214),
    accent: Color(0xFFE9C176),
    secondaryFill: Color(0xFF2D372F),
    text: Color(0xFFEDF2EB),
    textSoft: Color(0xFFC3C8C0),
    placeholder: Color(0xFFA9AFA7),
  );

  static AuthPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Scopes the auth palette over [child]: scaffold, filled borderless
/// fields with a 2px focus ring, and primary buttons/links. Only the auth
/// screens use it; the rest of the app keeps its own theme.
class AuthTheme extends StatelessWidget {
  const AuthTheme({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final p = AuthPalette.of(context);
    final radius = BorderRadius.circular(AppDimens.radiusLg);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );
    final scheme = base.colorScheme.copyWith(
      primary: p.primary,
      onPrimary: p.onPrimary,
      outlineVariant: Colors.transparent,
    );
    const family = AppFonts.authBody;
    const fallback = [AppFonts.arabic];
    return Theme(
      data: base.copyWith(
        colorScheme: scheme,
        textTheme: base.textTheme.apply(
          fontFamily: family,
          fontFamilyFallback: fallback,
        ),
        scaffoldBackgroundColor: p.background,
        appBarTheme: base.appBarTheme.copyWith(backgroundColor: p.background),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          fillColor: p.field,
          border: border(Colors.transparent),
          enabledBorder: border(Colors.transparent),
          disabledBorder: border(Colors.transparent),
          focusedBorder: border(p.primary, 2),
          errorBorder: border(scheme.error),
          focusedErrorBorder: border(scheme.error, 2),
          labelStyle: AppTextStyles.body.copyWith(color: p.placeholder),
          floatingLabelStyle: AppTextStyles.caption.copyWith(color: p.primary),
          hintStyle: AppTextStyles.body.copyWith(color: p.placeholder),
        ),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(
          fontFamily: family,
          fontFamilyFallback: fallback,
        ),
        child: child,
      ),
    );
  }
}

/// The brand mark (the app icon's ring and dot) in a soft circle, with the
/// Arabic and Latin wordmark under it. The app has no other logo asset.
class AuthEmblem extends StatelessWidget {
  const AuthEmblem({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final size = AppDimens.xxxl * 1.5;
    return ExcludeSemantics(
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: p.field, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Container(
              width: size * 0.66,
              height: size * 0.66,
              decoration: BoxDecoration(
                color: p.selected,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Container(
                width: size * 0.36,
                height: size * 0.36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: p.primary, width: size * 0.07),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: size * 0.1,
                  height: size * 0.1,
                  decoration: BoxDecoration(
                    color: p.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: AppDimens.md),
          Text(
            'حكايتنا',
            style: AppTextStyles.headline.copyWith(
              color: p.text,
              fontFamily: AppFonts.arabic,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'HEKAYETNA',
            style: AppTextStyles.caption.copyWith(
              color: p.accent,
              fontFamily: AppFonts.authDisplay,
              letterSpacing: 3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Two equal-width language choices filling the content width, in a soft
/// track; the selected one is raised and carries a check. Each name is in
/// its own language.
class AuthLanguageSwitch extends StatelessWidget {
  const AuthLanguageSwitch({required this.onChanged, super.key});

  final ValueChanged<Locale> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = AuthPalette.of(context);
    final current = Localizations.localeOf(context).languageCode;
    return Container(
      key: const Key('sign_in_language'),
      padding: EdgeInsets.all(AppDimens.xs),
      decoration: BoxDecoration(
        color: p.track,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Row(
        children: [
          for (final (label, locale) in [
            (l10n.languageEnglish, const Locale('en')),
            (l10n.languageArabic, const Locale('ar')),
          ])
            Expanded(
              child: _Segment(
                label: label,
                selected: current == locale.languageCode,
                onTap: () => onChanged(locale),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: AppDimens.targetMin),
          padding: EdgeInsets.symmetric(
            horizontal: AppDimens.sm,
            vertical: AppDimens.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? p.selected : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.label.copyWith(
                    color: selected ? p.onSelected : p.textSoft,
                  ),
                ),
              ),
              if (selected) ...[
                SizedBox(width: AppDimens.xs),
                Icon(Icons.check_rounded, size: 18, color: p.onSelected),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A form field in the approved auth direction: a persistent label above, a
/// white (dark: raised) rounded field with a soft shadow, a leading icon and
/// an optional trailing widget. The [TextField] keeps [fieldKey] so tests
/// and automation find it.
class AuthField extends StatelessWidget {
  const AuthField({
    required this.label,
    required this.controller,
    required this.icon,
    this.fieldKey,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.maxLength,
    this.onSubmitted,
    this.errorText,
    this.trailing,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final Key? fieldKey;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final int? maxLength;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: AppDimens.xs,
            bottom: AppDimens.sm,
          ),
          child: Text(
            label,
            style: AppTextStyles.label.copyWith(color: p.text),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            boxShadow: [
              BoxShadow(
                color: Color(dark ? 0x33000000 : 0x14000000),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            key: fieldKey,
            controller: controller,
            enabled: enabled,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            maxLength: maxLength,
            onSubmitted: onSubmitted,
            style: AppTextStyles.bodyLarge.copyWith(color: p.text),
            decoration: InputDecoration(
              fillColor: p.fieldRaised,
              errorText: errorText,
              counterText: '',
              prefixIcon: Icon(icon, color: p.placeholder),
              suffixIcon: trailing,
            ),
          ),
        ),
      ],
    );
  }
}

/// The show/hide toggle for a password [AuthField].
class AuthVisibilityToggle extends StatelessWidget {
  const AuthVisibilityToggle({
    required this.visible,
    required this.onChanged,
    super.key,
  });

  final bool visible;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final l10n = context.l10n;
    return IconButton(
      tooltip: visible ? l10n.authHidePassword : l10n.authShowPassword,
      onPressed: () => onChanged(!visible),
      icon: Icon(
        visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: p.textSoft,
      ),
    );
  }
}

/// The serif screen heading (one per auth screen, in the body, not the bar).
class AuthHeading extends StatelessWidget {
  const AuthHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Semantics(
      header: true,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTextStyles.headline.copyWith(
          color: p.text,
          fontFamily: AppFonts.authDisplay,
          fontFamilyFallback: const [AppFonts.arabic],
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
