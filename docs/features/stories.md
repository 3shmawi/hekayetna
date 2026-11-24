# Stories and player (spec 03)

## Layers
- Data: `StoryRepository`, `FamilyRepository`, `PhotoRepository` return
  `Future<Result<T>>` through `guard`. Implementations keep private raw
  methods and public guarded wrappers. Old callers use `.unwrap()` until
  their screens are rewritten (see `result.dart`).
- Errors: `FamilyFailure` (invalid invite code, member removed, not owner,
  cannot remove self, membership not found), mapped in `backend_errors.dart`.
- State: `story_providers.dart` (`currentSpaceProvider`,
  `storyFeedProvider(StoryFilter)`, `storyProvider(id)`, `personsProvider`,
  `membersProvider`, `storyActionsProvider`).
- Player: `player/audio_engine.dart` (fakeable just_audio wrapper) and
  `audio_player_controller.dart`. Refreshes the signed URL after 14 minutes
  or on a playback error. Speeds 0.75 to 1.5. Stops when the user changes.
- UI: pages read providers and pass plain values to views
  (`StoryFeedPage` to `StoryFeedView`, `StoryPage` to `StoryView`).
  `MiniPlayer` sits above the tab bar in `HomeShell` while a story plays and
  its page is not open.

## Analytics events (no titles, names or ids are sent)
`story_feed_filtered`, `story_opened`, `story_played`,
`story_speed_changed`, `story_deleted`, `story_edited`.

## Known gaps
Search, person-chip tap (spec 05), "selected people" visibility (spec 04),
dedicated goldens, and the demo integration test. See the PR checklist.
