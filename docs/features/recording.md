# Feature: recording that survives anything

Spec: [02-recording-recovery](../designs/02-recording-recovery.md).

## What it does
A story take is written to the phone continuously, so an app kill, a call or
a locked screen never loses recorded audio.

- A take is a list of **segments**. A new segment starts on start, on every
  resume and every 30 seconds of recording. `record` 7.2.0 has no ADTS
  encoder on either platform, so both iOS and Android use the spec's
  fallback: **WAV (PCM 16-bit, 44.1 kHz, mono)**. Rotation stops the old file
  then starts the next; the gap is tens of milliseconds (spec allows < 50 ms).
- The draft index (`drafts.json`) is written **before** the recorder starts,
  on every rotation, pause and resume, and every 5 s while recording. Writes
  are atomic (write then rename).
- On launch (`Dependencies.init` → `DraftRecovery`) a draft left `recording` or
  `paused` becomes `interrupted`: segments are re-measured, a cut-off WAV
  header is repaired, a zero-length last segment is dropped. A draft with no
  audible audio left is removed instead of offered for continuing.
- Interruptions (call, Siri, another app taking the microphone, unplugged
  headphones, capture error) auto-pause with `PauseReason.interruption`.
  Nothing ever resumes by itself.
- Low storage: under 50 MB free at start the take does not start
  (`storage_full` / `AppFailure.storageFull`); every 30 s during a take the
  same check pauses it with `PauseReason.storage`. Free space comes from a
  small native channel (`com.mohager.hekayetna/storage`: Android `StatFs`, iOS
  `volumeAvailableCapacityForImportantUsage`), no extra package.
- Save and preview join the segments into one WAV (`SegmentJoiner`): PCM is
  concatenated under a single header, so the uploaded size is the sum of the
  segments' audio plus one 44-byte header. Storage path stays
  `<space>/<uid>/<story>/a.wav`, content type `audio/wav`. The local draft is
  deleted only after the story row exists.

## Platform settings
- **iOS**: `UIBackgroundModes` = `audio` only (the `record` docs also list
  `fetch`; add it only if background audio fails without it).
  `NSMicrophoneUsageDescription` in `Info.plist` and in
  `en.lproj` / `ar.lproj` `InfoPlist.strings`.
- **Android**: `RECORD_AUDIO`, `FOREGROUND_SERVICE`,
  `FOREGROUND_SERVICE_MICROPHONE`, `POST_NOTIFICATIONS`, and the
  `flutter_foreground_task` 11.0.3 service declared with
  `foregroundServiceType="microphone"`, not exported. The service only holds
  the process in the foreground and forwards notification button presses;
  capture runs in the main isolate. Notification text follows the phone's
  language; buttons are Pause / Resume and Stop. If the notification
  permission is denied recording still works in the foreground.
- **Google Play**: the foreground service of type `microphone` must be
  declared in the Play Console "Foreground service permissions" form: purpose
  "recording a story the user is telling". The spec asks for this in
  `store/play_app_content.json`, which does not exist in this repository; see
  the PR "Deviations".

## Analytics events (planned, not wired yet)
`recording_started`, `recording_paused` {reason: user|interruption|storage},
`recording_resumed`, `recording_recovered` {segments, minutes_bucket},
`recording_discarded`, `recording_finished` {minutes_bucket}. No names or
titles.

## Tests
`test/features/segmented_recorder_service_test.dart` (AC-1, AC-2, AC-5, AC-10
data), `test/features/draft_recovery_test.dart` (AC-3, AC-8),
`test/features/recording_background_binder_test.dart`,
`test/security/platform_config_test.dart` (AC-9).

## Manual device test (not run yet)
On a real iPhone and a real Android phone: record 2 minutes with the screen
locked; take a phone call mid-recording; swipe the app away mid-recording and
reopen; airplane mode then save (offline state, upload when back online).
Each must keep every second recorded before the event. Results go in the PR.

## Not built yet
The Continue-a-recording screen (AC-6/AC-7 UI) waits for the `RecordResume`
artboard.
