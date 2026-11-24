# Spec 08 · Elder mode (الوضع السهل)

Status: ready for review · PR title: `feat: elder mode with two big buttons`
Branch: `feat/08-elder-mode` · Depends on: 01–04, 07 · Flag: `elder_mode`

## Why

The people with the best stories often find apps hard: small text, many
buttons, menus. Elder mode turns the app into two huge buttons, set up once
by a family member on the elder's own phone.

## Design references

- Elder home: `#artboard-IdeaElderMode` (page "Ideas", Arabic)
- Design System: Button (sizes), RecordButton

## Code to read first

`lib/features/settings/**`, `lib/core/router/app_redirect.dart`,
`lib/core/router/app_router.dart`, recording/save flows from specs 02 and 04,
prompts from spec 07.

## Scope

### 1. Turning it on and off

- Settings → **Elder mode** (new tile with a one-line explanation): "Two big
  buttons, large text. For the grandparent's own phone." Turning on asks
  "Who is this phone for?" (pick the person from the family tree, defaults
  to the person linked to this account) and confirms.
- Stored on the device only (`SharedPreferences`: `elder_mode_person_id`,
  `elder_mode_set_by_name`), never synced.
- When on, the router redirects every in-app destination except recording,
  the elder listen screen, the elder home and system routes (sign-in, update
  gate) to `/easy` (new route, name `elder_home`). Deep links into other
  screens land on the elder home.
- Turning off: **long-press the name for 2 seconds** on the elder home → a
  confirmation "Turn off elder mode?" with the normal-size app's options.
  The hint line at the bottom says exactly this.

### 2. Elder home (`ElderHomePage`), per artboard IdeaElderMode

- Avatar 64 px, greeting "Hello, Sitto Fatma" / "أهلًا يا ستو فاطمة"
  (display name + family nickname from the person record), and a second line:
  the newest thing for them ("Omar asked you a new question" when the
  question of the week targets them; else "{n} new family stories" when
  there are unheard stories; else nothing).
- **Tell a story** (record colour, ≥ 250 px tall, icon 72 px, label 30 px):
  shows the current question under the label. Opens the elder recording flow.
- **Listen to the family** (primary colour, ≥ 200 px tall): opens the elder
  listen screen.
- Text sizes ignore the user's smaller font setting (never smaller than the
  artboard) and still grow with larger accessibility sizes.

### 3. Elder recording flow

- The normal recording screen (spec 04) with: narrator fixed to this
  person (no chip), the prompt card, and only two controls: the record
  button and a big **Done**. No topic button.
- After Done, one question, full screen, two big buttons: **Share with the
  family** / **Keep it just for me** (default focus on "Keep it just for
  me"). The title is the prompt question, or "A story from {date}"; the
  family can edit details later. Saved with the spec 04 save logic
  (upload progress shown as a large bar and "Saving your story…").
- Success: "Thank you! The family will love this." and back to the elder
  home after 3 seconds or a tap.

### 4. Elder listen screen

A vertical list of very large cards (title 24 px, narrator, duration), one
tap plays/pauses inline, newest first, "new" badge on unheard ones (local
"heard" set). No filters, no menus.

## Acceptance criteria

- **AC-1** Turning on/off works as specified; state is device-local (test).
- **AC-2** Router redirects to `/easy` when on (unit tests for allowed and
  redirected paths, deep-link security cases for `/easy`).
- **AC-3** Elder home matches the artboard (goldens en/ar, light/dark, and at
  200% text size without clipping).
- **AC-4** All tap targets ≥ 72 px on elder screens (test).
- **AC-5** Elder recording: no narrator/topic controls; share question
  defaults to keep private; save works offline-safe (spec 02 rules).
- **AC-6** Long-press 2 s on the name opens the turn-off confirmation; a
  short tap does nothing.
- **AC-7** Integration test (demo style): turn on for Sitto, tell a story,
  keep it private, listen to the family, turn off.
- **AC-8** `docs/features/elder_mode.md`.

## Analytics

`elder_mode_enabled`, `elder_mode_disabled`, `elder_story_recorded`
{shared: bool}, `elder_listen_played`.
