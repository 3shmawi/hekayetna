# Spec 01 · Design foundation

Status: ready for review · PR title: `feat: design system foundation (tokens, theme, shared widgets, tab bar)`
Branch: `feat/01-design-foundation` · Depends on: nothing · Flag: none

## Why

The app's look is defined in the Design System, but the code still uses a
Material seed theme, 14px body text and raw Material widgets in every
feature screen. Every later spec builds screens from the pieces this spec
adds, so nothing visible changes in behaviour here: it is the toolbox.

## Design references

- Design System: <https://claude.ai/artifact/3DTUAPe6vLSCwpSGRNhCv1>
  (`README.md`, `tokens.json`, every component card).
- Tab bar: artboards `#artboard-Main` and `#artboard-Family` on
  <https://claude.ai/artifact/B5gEE7QpXmeEE4EPiUDuw1>.

## Code to read first

`lib/core/theme/*.dart`, `lib/core/ui/app_ui.dart`,
`lib/core/adaptive/adaptive.dart`, `lib/core/widgets/state_views.dart`,
`lib/core/router/app_router.dart` (`HomeShell`), `test/golden/golden_test.dart`,
`test/helpers/pump_app.dart`.

## Scope

### 1. Tokens → code

Replace values exactly with the Design System `tokens.json` (light / dark):

| Token | Light | Dark | Code |
|---|---|---|---|
| sand | #F6F1E7 | #171512 | `AppColors.sand` / `sandDark`; scaffold background |
| surface | #FFFDF8 | #211E1A | cards, sheets (`colorScheme.surface`) |
| surface-raised | #FFFFFF | #2B2722 | inputs, selected cards (`surfaceContainerHigh`) |
| line | #E2D9C8 | #3A342C | borders, dividers (`outlineVariant`) |
| ink | #25211D | #F3ECE1 | text (`onSurface`) |
| ink-soft | #5A645C | #B4BDB5 | secondary text (`onSurfaceVariant`) |
| olive | #3F6B5C | #8DB8A6 | `primary` |
| olive-deep | #2F5246 | #A9CDBD | pressed primary |
| on-olive | #FFFFFF | #10241C | `onPrimary` |
| olive-tint | #E3ECE6 | #22332C | `primaryContainer`, selected chips |
| terracotta | #9C4A21 | #E08A5C | recording only (`AppColors.record`) |
| on-terracotta | #FFFFFF | #2A1408 | |
| terracotta-tint | #F3E1D6 | #3A2418 | record halo, draft badges |
| gold | #C9A227 | #D9B84A | small accents only, never text on light |
| gold-tint | #F5ECD0 | #332B14 | demo band, "sample" tags |
| error | #B3261E | #F2B8B5 | `error` |
| error-tint | #F9DEDC | #3C1B19 | `errorContainer` |

- Build `ColorScheme` explicitly from these (not `fromSeed`) for both
  brightnesses in `AppTheme`. Expose the extra brand colours through a
  `ThemeExtension<HekayetnaColors>` (`record`, `onRecord`, `recordTint`,
  `gold`, `goldTint`, `line`, `inkSoft`, `sand`) read via
  `context.hk` (an extension getter in `app_theme.dart`).
- Type scale in `AppTextStyles` (`.sp`, Inter with Cairo fallback as today):
  `display` 32/40 w700 · `headline` 26/34 w700 · `title` 21/28 w600 ·
  `bodyLarge` 19/30 · `body` 17/26 · `label` 16/22 w600 · `caption` 15/21 ·
  `timer` 44/52 w600 tabular figures. **Nothing smaller than 15** except tab
  labels (12/16 w600) and count badges (13 w700).
- `AppDimens`: spacing `xs 4, sm 8, md 12 (new), lg 16, xl 24, xxl 32,
  xxxl 48` (rename carefully and update call sites), radii `sm 8, md 14,
  lg 22, pill 999`, sizes `targetMin 48, buttonHeight 56, avatar 44,
  playButton 72, recordButton 96`.
- Light theme cards use the `shadow-card` shadow; dark theme uses no
  shadow, only surface steps.

### 2. Shared widgets (in `lib/core/ui/`, exported from `app_ui.dart`)

Each is a stateless widget taking data + callbacks, adaptive where noted,
with golden and widget tests. Visuals follow the Design System cards.

| Widget | API (sketch) | Notes |
|---|---|---|
| `AppScaffold` (update) | `title`, `actions`, `leading`, `body`, `bottom` (sticky bottom area), `background` | Cupertino nav bar on iOS, no Material `AppBar` look; background = sand |
| `AppButton` | `AppButton.primary/secondary/destructive/record(label, onPressed, icon?, expand?)`, `busy` | height 56, radius md, label **never wraps** (single line, ellipsis), busy shows a small progress indicator and keeps the width |
| `AppChip` | `label`, `selected`, `onTap`, `leading?` (avatar), `trailing?` | pill, min height 48 |
| `PersonAvatar` | `name`, `photoUrl?`, `size`, `tone: olive|terracotta` | initial on tint when no photo; semantics = name |
| `StoryCard` | `title`, `narratorName`, `dateLabel?`, `duration`, `topicLabel?`, `isSample`, `onOpen`, `onPlay` | layout per Design System card; title max 2 lines |
| `AudioPlayerCard` | `title?`, `subtitle`, `position`, `duration`, `isPlaying`, `speed`, `onToggle`, `onSeek`, `onSpeed`, `waveform` (List<double> 0–1) | waveform doubles as the scrubber, mirrors in RTL, semantics as a slider |
| `RecordButton` | `state: idle|recording|paused`, `onPressed` | 96 px terracotta pill, 140 px breathing halo while recording (off with reduce motion), semantics "Start/Pause/Resume recording" |
| `VisibilityPicker` | `value`, `onChanged`, `consequenceText` | three large options + consequence row |
| `AppSectionLabel` | `text` | small uppercase label (Arabic: no uppercase, 15px) |
| `SkeletonCard` | `lines` | loading placeholder |
| `EmptyView` / `ErrorView` (update) | add `title`, `actionLabel`, `onAction`, icon on tint circle | per Design System StateView |

### 3. Icons

Add to `AdaptiveIcons` (SF Symbol look on iOS, Material outlined on
Android): `record` (mic), `play`, `pause` (play/pause mirror rules: play
mirrors in RTL), `stories` (waveform), `family`, `search`, `invite`
(person.badge.plus), `close`, `more`, `lock`, `share`, `zoomIn`, `zoomOut`,
`fitAll`, `centerMe`, `bookmark`, `checkCircle`, `calendar`, `photo`.

### 4. Tab bar (`HomeShell`)

Replace the Material `NavigationBar` with `AppTabBar` in `app_ui.dart`:
three items **Stories · [Record] · Family**. The centre item is a 64 px
terracotta circle with a mic icon, raised 28 px above the bar with a 4 px
sand ring (see artboard Main). Bar: frosted (blur 18, surface at 82%),
hairline top border, safe-area aware. Selected item colour `primary`, others
`onSurfaceVariant`. Labels 12/16 w600. Each item ≥ 48×48 and has a semantics
label; the record item reads "Record a story". Tapping the current tab
pops to its root (keep today's `goBranch` behaviour).

### 5. Migrate the shared screens only

Move `settings`, `auth` (sign-in, account, new password), `onboarding` and
`not_found` screens to the new tokens/widgets where they use raw Material
(they mostly use `AppScaffold` already). **Do not** touch stories, record or
family screens; specs 03–05 rebuild them.

## Out of scope

New features, data changes, the stories/record/family screens.

## Acceptance criteria

- **AC-1** `AppTheme.light/dark` use the exact token colours (unit test
  compares every `ColorScheme` role and `HekayetnaColors` field to the table).
- **AC-2** All text styles match the scale; a test asserts no style used by
  shared widgets is below 15sp except the two named exceptions.
- **AC-3** Each shared widget has widget tests (states, callbacks, semantics,
  RTL mirror where relevant, 200% text scale doesn't overflow) and goldens
  light/dark × en/ar.
- **AC-4** `AppButton` label never wraps: golden with a long Arabic label in
  a half-width button shows one line with ellipsis.
- **AC-5** `AppTabBar` matches artboard Main; widget test: three targets
  ≥ 48, record item semantics label, tapping switches branches.
- **AC-6** `RecordButton` halo animation is off when
  `MediaQuery.disableAnimations` is true (test).
- **AC-7** Settings, auth, onboarding screens render with the new theme; their
  goldens are updated and every PNG was looked at.
- **AC-8** No `Icons.` in `lib/core/ui` or `lib/features/{settings,auth,onboarding}`
  except inside `AdaptiveIcons`.
- **AC-9** `docs/design.md` "Tokens → code" table updated to the new names.

## Analytics

None new.
