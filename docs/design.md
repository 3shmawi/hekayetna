# Design

The UI is designed first in Claude (Design System + Design artifacts), then
built to match. Code never invents its own look.

| Source | Link |
|---|---|
| Design System (tokens, components, guidelines) | [Hekayetna Design System](https://claude.ai/artifact/3DTUAPe6vLSCwpSGRNhCv1) |
| Screens (Design canvas) | [Hekayetna App Screens](https://claude.ai/artifact/B5gEE7QpXmeEE4EPiUDuw1): feed, story, recording, who can listen, family, welcome; Arabic + dark |
| App icon / store screenshots | <!-- claude.ai/artifact/… --> |

## Tokens → code
| Design System token | Code |
|---|---|
| Colors (light + dark) | `lib/core/theme/app_colors.dart` → `AppColors` (light values) + `HekayetnaColors.dark` → `AppTheme.light/dark` (`ColorScheme` roles + the `HekayetnaColors` theme extension: `record`, `onRecord`, `recordTint`, `gold`, `goldTint`, `line`, `inkSoft`, `sand`) |
| Type scale, font family | `lib/core/theme/app_text_styles.dart` (`AppTextStyles`), fonts in `lib/core/theme/app_fonts.dart` (`AppFonts.latin` / `AppFonts.arabic`) |
| Spacing, radius, sizes | `lib/core/theme/app_dimens.dart` (`AppDimens`, 375×812 design size) |
| Components (buttons, cards, chips, player, record, visibility, tab bar…) | `lib/core/ui/` exported from `app_ui.dart`: `AppButton`, `AppChip`, `PersonAvatar`, `StoryCard`, `AudioPlayerCard`, `RecordButton`, `VisibilityPicker`, `AppSectionLabel`, `SkeletonCard`, `EmptyView`, `AppTabBar` |
| Icons (Material/Cupertino) | `lib/core/adaptive/adaptive.dart` → `AdaptiveIcons`; feature code never touches `Icons.` directly |

When the Design System changes, update these files first, then screens.

## UI style: adaptive
Screens use `lib/core/ui/app_ui.dart` (`AppScaffold`, `AppCard`,
`AppIconButton`). With **glass** (Liquid Glass, iOS 26/27 look via
`liquid_glass_widgets`):
- Glass needs content behind it: give image-rich screens a photo
  `background:`; others get the brand gradient (`AppBackground`).
- At most two glass layers on top of each other; lists of many cards use
  `GlassQuality.minimal` to keep scrolling smooth on mid-range Android.
- Text on glass must stay ≥ 4.5:1 — test on the busiest photo, in light and
  dark, and with iOS 27's transparency slider at "clear".
- Accessibility: Reduce Motion and Increase Contrast are respected
  automatically; tests run with solid surfaces (`AppUi.testWrap`).
- Lite mode (`AppUi.isLite`: Reduce Transparency / Increase Contrast,
  widget tests, or `--dart-define=GLASS_LITE=true` for GPU-less devices)
  draws plain surfaces: no shader, no blur, no blurred shadow, no screen
  capture. New glass widgets in `app_ui.dart` need the same lite branch.
- `AppScaffold` places the body **below** the glass bar
  (`GlassScaffold(extendBody: false)`): screens add no spacer for the bar.
  The bar: `leading` at the start edge (default: back when the page can
  pop), the title after it, `actions` at the end edge; icon buttons are
  48×48. `test/core/ui/app_scaffold_test.dart` checks the glass bar in
  English and Arabic, because screen tests draw the lite bar.
- A screen that ends in a dock passes `padBottom: false` and pads the dock
  itself (`SafeArea(top: false)`), so the dock reaches the bottom edge.
- iOS icons come from `CupertinoIcons` (`core/adaptive/`), whose font is the
  `cupertino_icons` package: without it every iOS icon is a "?" box.
- When Flutter ships official Cupertino Liquid Glass, swap the
  implementation inside `app_ui.dart` only.

## Fonts
`AppFonts.latin` + `AppFonts.arabic` (lib/core/theme/app_fonts.dart), bundled
from Google Fonts in `assets/fonts/` (static TTF per weight, licenses shown on
the app's licenses page). Arabic characters fall back to the Arabic font
automatically. To change fonts: run
`python3 <kit>/kit_tools/fetch_fonts.py assets/fonts "<Latin>" "<Arabic>"`,
update the `fonts:` section in pubspec.yaml and the two constants.

## App icon & splash
`assets/branding/` holds a placeholder generated in the primary color.
Export the real icon from Claude Design and overwrite (same names/sizes):
`icon.png` (1024, no transparency), `icon_foreground.png` (1024, transparent,
mark inside the middle 66%), `icon_dev.png` / `icon_staging.png` (flavors),
`splash.png` (768, transparent). Then:
```bash
dart run flutter_native_splash:create
dart run flutter_launcher_icons            # single-flavor projects
dart run flutter_flavorizr -p android:icons,ios:icons   # projects with flavors
```

## Screen checklist (each screen in the design → code)
- Matches the design at 375×812, and still works on a small phone (320 wide),
  a large phone and a tablet.
- Has all states: loading (skeleton/adaptive spinner), empty, error with
  retry, success, offline.
- Arabic RTL and dark mode checked.
- Touch targets ≥ 48×48, text contrast ≥ 4.5:1, works with large text
  (system font scale 1.3+), every icon button has a semantics label/tooltip.
- Motion: short (150–300 ms), purposeful; respects "reduce motion".
- Platform-adaptive: iOS look on iOS (Cupertino), Material on Android.
