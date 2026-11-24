# Feature: onboarding (first-launch welcome)

## What it does
A new install opening the app sees a short progressive welcome (`/welcome`)
once, then lands on home. Instead of passive slides, the tree starts
growing on screen: welcome, your name, your parents (optional), ready.
Skip, Back and Next/Get started are always there. Deep links into other
screens skip it.

The names are kept on the device as a draft; nothing is created during the
welcome itself. The Family tab then shows a one-time "Start your tree"
card offering to add exactly those names (you, then each parent with a
parent relationship). Confirming adds them; dismissing drops the draft.

## Make it yours
- text: the `onboarding*` keys in **both** `lib/l10n/app_en.arb` and
  `app_ar.arb`;
- the tree sketch: `_SeedTree` in `presentation/onboarding_page.dart`;
- steps: `_steps` and `_buildStep` in the same file.

## Architecture
- `lib/features/onboarding/data/onboarding.dart` — `Onboarding.seen` and
  `Onboarding.draft` (SharedPreferences, loaded in
  `core/di/dependencies.dart`), `OnboardingDraft`, and
  `onboardingRedirect` (used by `core/router/app_redirect.dart`).
- `presentation/onboarding_page.dart` — the steps, the growing-tree
  sketch, analytics, completion.
- `features/family/presentation/family_screens.dart` — the seed card that
  turns a saved draft into real persons and relationships, once.
- Integration tests call `skipFirstLaunch(tester)` after `app.main()`
  (`integration_test/helpers/demo.dart`).

## Tests
- `test/features/onboarding/onboarding_test.dart` — redirect, saved state,
  draft round-trip, step walk-through, Back, Skip, accessibility, and the
  seed card (add and dismiss paths).

## Analytics events
| Event | Properties |
|---|---|
| `onboarding_completed` | `skipped`: bool |

## Demo & post
- Hook: "Your family tree starts growing before you even sign in."
