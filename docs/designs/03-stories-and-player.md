# Spec 03 · Stories feed, story page and player

Status: ready for review · PR title: `feat: premium stories feed, story page and player`
Branch: `feat/03-stories-and-player` · Depends on: 01 · Flag: none

## Why

The home screen and the story page are what families see most. Today they
use `FutureBuilder`s that refetch on every rebuild (the feed flickers), raw
Material widgets, generic error snackbars, and there is no way to edit or
delete a story.

## Design references

- Stories feed: `#artboard-Main` (light, en), `#artboard-FeedArDark` (dark, ar)
- Story page: `#artboard-StoryDetail`
- Design System: StoryCard, AudioPlayer, PersonChip, StateView, Button

## Code to read first

`lib/features/stories/**`, `lib/features/family/data/family_repository.dart`,
`lib/features/photos/data/**`, `lib/app/app_providers.dart`,
`lib/core/network/result.dart`, `lib/core/router/app_routes.dart`.

## Scope

### 1. Data layer

- Change `StoryRepository`, `FamilyRepository` and `PhotoRepository` to return
  `Future<Result<T>>` with every Supabase call inside `guard`. Map Postgres
  errors from the RPCs (`invalid_invite_code`, `member_removed`, …) to typed
  `AppFailure`s (new kinds as needed, with ARB messages). Update the demo
  repositories and all callers (stories, record, family screens) in the same
  PR so `main` stays green.
- Riverpod: `currentSpaceProvider` (AsyncNotifier, cached, refreshed after
  create/join), `storyFeedProvider(StoryFilter)` (AsyncNotifier with
  `refresh()`), `storyProvider(id)`. Pull-to-refresh calls `refresh()`.
- Add `deleteStory` flow: deletes the row, then the audio object (row first:
  if the object delete fails the file is unreachable anyway; log it to
  monitoring, don't show an error).

### 2. Stories feed (`StoryFeedPage` → `StoryFeedView`)

Per artboard Main:
- Header "Stories" (`headline`), search and account/settings icon buttons.
- Filter row (horizontal, scrollable, never wraps): **All**, then one chip
  per narrator who has stories (most stories first), then topics, then
  decades that have stories ("1950s"). One chip selected at a time per kind;
  selecting narrows the list. "All" clears filters.
- A slot for the "question of the week" card (spec 07 fills it; in this
  spec, render nothing).
- Section label "Recently added", then `StoryCard`s. Tapping a card opens the
  story; tapping its play button plays inline (mini player, see 4).
- Demo band (gold tint) when `isDemoModeProvider` is true, as today.
- States: skeleton cards while loading; empty (no stories yet) with the
  Design System copy and a **Record the first story** button that opens the
  Record tab; error with Retry; the global offline banner.
- No space yet: the create-or-join view (move today's `_NoSpace` into its own
  widget, styled per Design System; spec 06 polishes invites).
- Remove the floating "Record a story" button: the tab bar's centre button
  (spec 01) replaces it.

### 3. Story page (`StoryPage` → `StoryView`)

Per artboard StoryDetail:
- Back, share-to-family (lock icon opens the visibility sheet, creator only),
  and a "More" menu (creator only): **Edit details**, **Who can listen**,
  **Delete story**. Non-creators see no More menu.
- Topic tag, title (`display`), date label + "Recorded by {name}".
- `AudioPlayerCard`: narrator ("Told by Sitto Fatma"), big play/pause,
  waveform scrubber (if the story has no waveform data yet, show a plain
  progress track of the same height), elapsed / total, speed 0.75× / 1× /
  1.25× / 1.5×.
- Description (`bodyLarge`), "In this story" person chips (tap opens the
  person in the family tree, spec 05), photos grid (existing behaviour,
  locked frames for inaccessible photos), visibility note at the bottom
  ("The whole family can hear this (8 people)" / "3 people can hear this:
  Mama, Omar, Nour" / "Only you can hear this").
- Delete: a sheet "Delete this story? Everyone loses access and the recording
  is removed. You can't undo this." with Cancel / Delete. Then back to the
  feed with a message "Story deleted".
- Edit details opens the story form from spec 04 when it exists; until
  then, a sheet that edits title, description and date only, via
  `updateStory`.
- States: loading skeleton; not found / no access ("This story isn't shared
  with you"); error with Retry.

### 4. Player

- One `AudioPlayerController` (Notifier) app-wide, wrapping just_audio:
  load (signed URL), play/pause, seek, speed, position stream, completion.
- Signed URLs live 15 minutes: when playback starts or resumes after the URL
  expired (or a 400/403 comes back), fetch a new URL and continue from the
  same position, silently.
- Mini player: when a story plays and the user leaves its page, a compact
  bar above the tab bar shows title, play/pause and progress; tap returns to
  the story. Stops on sign-out.
- Lock-screen controls and background playback: **out of scope** here (needs
  a new package; propose it in a follow-up issue).

## Acceptance criteria

- **AC-1** Repositories return `Result`; tests cover Success and Failed for
  every method (Supabase repositories tested with a fake/mocked client via
  mocktail; demo repositories directly).
- **AC-2** The feed doesn't refetch on rebuild (test counts repository calls
  across rebuilds = 1) and refreshes on pull-to-refresh.
- **AC-3** Filters: widget tests for narrator, topic and decade chips and
  "All"; chips never wrap (golden with long Arabic names).
- **AC-4** Feed and story page match their artboards; goldens light/dark ×
  en/ar, including the empty, loading and error states.
- **AC-5** Creator sees More with Edit / Who can listen / Delete; a
  non-creator doesn't (widget tests with both users).
- **AC-6** Delete removes the row then the file, shows the message and
  returns to the feed; a failed delete shows the error and keeps the story.
- **AC-7** Player: play/pause/seek/speed and expired-URL refresh are unit
  tested with a fake player; the waveform scrubber is a semantics slider
  and mirrors in RTL.
- **AC-8** Mini player appears when leaving a playing story and returns to it.
- **AC-9** Integration test (demo style): open the app in demo mode, filter
  by Sitto, open "The first Om Ali", play, change speed, go back, see the
  mini player.
- **AC-10** `docs/features/stories.md` (new) with screens, states, events.

## Analytics

`story_feed_filtered` {kind: narrator|topic|decade}, `story_opened`,
`story_played` {from: feed|page}, `story_speed_changed` {speed},
`story_deleted`, `story_edited`.
