# Spec 04 · Record screen and "who can listen"

Status: ready for review · PR title: `feat: redesigned recording and save-story flow`
Branch: `feat/04-record-and-share` · Depends on: 01, 02, 03 · Flag: none

## Why

Recording is the heart of the app. Spec 02 makes it safe; this spec makes
it feel calm and simple, and makes sharing impossible to get wrong.

## Design references

- Recording: `#artboard-Record` (light, en), `#artboard-RecordArDark` (dark, ar, paused)
- Save the story / Who can listen: `#artboard-WhoCanListen`
- Design System: RecordButton, VisibilityPicker, PersonChip, Button

## Code to read first

`lib/features/recording/presentation/**`,
`lib/features/stories/presentation/story_screens.dart` (`StoryEditScreen`),
`lib/features/stories/domain/story_topics.dart`,
`supabase/migrations/0003_family_schema.sql` (stories, recipients),
`supabase/migrations/0007_family_fixes.sql`.

## Scope

### 1. Recording screen (`RecordPage` → `RecordView`)

Per artboards Record and RecordArDark:
- Top: close (×) "Close, the draft is kept" and the line "Draft saved on
  this phone" (shown once spec 02 has saved the draft).
- **Speaking** chip: the narrator (a person from the family tree). Tapping
  opens a sheet to pick a person or "Add a person" (name only). Default: the
  last narrator used.
- Prompt card "Ask her / him": the question being answered (from spec 07
  when started from a question; otherwise a random question for the
  narrator's next unanswered topic, with a "Different question" link; hide the
  card when the user has turned prompts off in settings).
- Timer (`timer` style), status ("Recording" with terracotta dot / "Paused"),
  a live level meter (20 bars driven by `AudioRecorder.onAmplitudeChanged`
  every 100 ms; no animation when reduce motion is on), and the
  `RecordButton` (start / pause / resume).
- Bottom: **Topic** (opens topic picker sheet) and **Done** (primary; only
  enabled once something has been recorded). Done stops the recorder and
  opens the save screen.
- While recording, also keep the amplitude samples (one value per 250 ms) to
  build a 64-bar waveform for the player (see 3).
- Remove the separate "Recording preview" screen; its job (listen back,
  record again, delete) moves into the save screen.

### 2. Save the story (`SaveStoryPage`)

Per artboard WhoCanListen:
- Header "Save the story" with back (returns to recording, which continues
  the same draft).
- A compact player of the take (listen back), with **Record again**
  (asks once, then deletes the take and returns to recording) and **Delete**.
- Title field (required, 1–140 chars, trimmed; error text under the field
  when empty on save), optional description (≤ 2000), approximate date (free
  text ≤ 60 + optional year 1800–2100), narrator(s), people in the story,
  topic, photos (pick existing family photos; adding new photos stays in the
  family screens).
- **Who can listen?** `VisibilityPicker`: Only me (default, always) ·
  Selected people (shows member chips; at least one must be selected to
  save) · The whole family ("Everyone in the family now. People who join
  later won't."). The consequence line is always visible and exact:
  "Only you can hear this" / "3 people can hear this: Mama, Omar, Nour" /
  "Everyone in the family now (8 people)".
- **Save story** (primary, sticky at the bottom): joins segments (spec 02),
  uploads with a progress indicator ("Uploading 40%"), creates the story with
  narrators, people, photos and recipients, then opens the new story page
  with a message "Story saved". On failure: keep everything on screen, show
  the error with Retry; the draft stays on the phone until success.
- Offline: Save is disabled with the line "You're offline. Your story is
  safe on this phone; save it when you're back online."
- The same form, prefilled and without the audio section, is the **Edit
  details** screen used by spec 03.

### 3. Waveform (backend)

New migration `0008_story_waveform.sql`: `alter table stories add column
waveform smallint[] check (waveform is null or (array_length(waveform,1) <= 128
and 0 <= all(waveform) and 100 >= all(waveform)))`. Write the 64 values
(0–100) on create. RLS is unchanged (column on an existing table); add a
pgTAP assertion that a member can't update another member's story waveform.
Spec 03's player reads it.

## Acceptance criteria

- **AC-1** Recording and save screens match their artboards (goldens
  light/dark × en/ar, recording and paused states).
- **AC-2** Narrator chip and topic sheet work; the narrator defaults to the
  last one used (persisted in settings).
- **AC-3** Done is disabled until audio exists; Done → save screen.
- **AC-4** Save validates: empty title, "Selected people" with nobody, too
  long fields (tests with hostile input: 10 000 chars, `<script>`, SQL-like
  strings, RTL override characters; text is stored as typed and rendered as
  plain text).
- **AC-5** The consequence line is exact for all three choices (unit test of
  the sentence builder in both languages, including Arabic plural forms via
  ICU plurals in the ARB files).
- **AC-6** Save success: story created with the right recipients (repository
  test asserts the inserts); failure keeps the form and the draft.
- **AC-7** Offline: Save disabled with the offline line (widget test with
  connectivity overridden).
- **AC-8** Migration 0008 + pgTAP tests pass; the player shows the waveform
  when present.
- **AC-9** Record again / Delete ask once and do what they say.
- **AC-10** Integration test (demo style): open Record from the tab bar, pick
  Sitto, record, pause, resume, Done, type a title, choose Selected people,
  pick two members, save, land on the story page.
- **AC-11** `docs/features/recording.md` updated; old preview route removed
  from `AppRoutes`, `app_router.dart`, `docs/deep_links.md` and its security
  test updated.

## Analytics

`story_saved` {visibility, narrators_count, has_photos, minutes_bucket},
`story_save_failed` {failure_kind}, `recording_narrator_changed`,
`recording_take_discarded`.
