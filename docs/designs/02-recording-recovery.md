<!-- Note for the EGM review: this spec changes on-device data storage and
platform permissions; per CLAUDE.md it is a "big feature". The owner asked
for it to be the first feature. -->

# Spec 02 · Recording that survives anything

Status: ready for review · PR title: `feat: recordings survive app close, calls and screen lock`
Branch: `feat/02-recording-recovery` · Depends on: 01 · Flag: none (it is a fix)

## Why

Today a story is lost if the app is killed, the phone locks, or a call comes
in while recording:

1. The draft is written to the index only when the user taps Done
   (`RecordScreen._finish`), so a killed app leaves no trace of the take.
2. The take is a single `.m4a` (AAC in MP4). MP4 writes its index at the
   end, so a file cut off by a crash is unplayable.
3. iOS has no `audio` background mode: recording stops when the screen locks.
4. Android has no foreground service: the OS may stop the microphone in the
   background.
5. Interruptions (calls, Siri, another app taking the mic) are not handled.

An elder telling a 20-minute story must never lose it.

## Design references

- Recording (live): `#artboard-Record`, `#artboard-RecordArDark`
- Continue a recording: `#artboard-RecordResume`
- Design System: RecordButton, StateView
  (<https://claude.ai/artifact/B5gEE7QpXmeEE4EPiUDuw1>,
  <https://claude.ai/artifact/3DTUAPe6vLSCwpSGRNhCv1>)

## Code to read first

`lib/features/recording/**`, `lib/features/stories/data/models.dart`
(`StoryDraft`), `lib/core/di/dependencies.dart`,
`lib/features/stories/presentation/story_screens.dart` (`StoryEditScreen._save`
uploads the draft), `ios/Runner/Info.plist`,
`android/app/src/main/AndroidManifest.xml`,
`test/features/recorder_transitions_test.dart`,
`test/features/file_draft_store_test.dart`.

## Before coding: check the official docs (CLAUDE.md rule)

The architect checked these on 2026-11-24 for `record` **7.2.0** (pinned in
`pubspec.yaml`); re-read them and note the date in the PR:

- `record` 7.x **removed its Android background service** (7.0.0 breaking
  change). Its doc `doc/bg_recording.md` says to use an external package for
  background recording: use **`flutter_foreground_task` 11.0.3** (exact pin)
  and follow its `record_service` example.
- `record` 7.2.0 adds `RecordConfig.audioRouteChange` (what a take does when
  its input disappears: use **pause**) and `onStopped()` with a
  `RecordStopReason` for every take: use them for interruptions.
- `record` 7.1.0: read the effective config from `onConfigChanged` (the
  platform may clamp sample rate or bitrate); store what was really used.
- iOS: `UIBackgroundModes` → `audio` in `Info.plist` (the `record` docs also
  list `fetch`; add only `audio` unless background audio fails without it,
  and say so in the PR). With `AudioInterruptionMode.pauseResume` the audio
  session must include `IosAudioCategoryOptions.mixWithOthers`.
- Android: foreground service type `microphone` (Android 14+:
  `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MICROPHONE` permissions), the
  notification permission on Android 13+, and Google Play's
  foreground-service declaration (record it in `store/play_app_content.json`).

## Design of the solution

### Recording in segments

- A take is a list of **segments**. A new segment file starts on start, on
  every resume, and automatically every **30 seconds** of continuous
  recording (rotate: start the next file, then stop the previous, so no
  audio is dropped; if the plugin can't overlap, accept a gap under 50 ms
  and document it).
- Encoder: **AAC in ADTS** (`.aac`) when supported on the platform
  (`AudioRecorder.isEncoderSupported`); ADTS frames are self-contained, so
  a cut-off file still plays up to the cut, and segments join by simple byte
  concatenation. If ADTS isn't supported on a platform, fall back to WAV
  (PCM 16-bit, 44.1 kHz mono) segments and repair the header of a cut-off
  WAV on recovery. Say in the PR which encoder each platform uses.
- Mono, 44.1 kHz, 64 kbps AAC (speech quality, ~0.5 MB/min).

### The draft is saved continuously

Extend `StoryDraft` (keep JSON backward compatible: old drafts load as one
segment):

```dart
class StoryDraft {
  String id; DraftStatus status; // recording | paused | interrupted | finished
  List<DraftSegment> segments;   // {path, durationMs, closed}
  String? narratorPersonId; String? topic; String? promptId;
  DateTime createdAt; DateTime updatedAt;
  Duration get duration;         // sum of segments
}
```

- The draft is written to the index **when recording starts**, and again on
  every segment rotation, pause, resume and every 5 seconds while recording
  (`durationMs` of the open segment). Index writes stay atomic
  (write-then-rename, as today).
- `DraftStore` gets `Future<String> newSegmentPath(String draftId)` and owns
  the drafts directory; remove the `(… as dynamic).directoryPath` hack in
  `record_screen.dart`.
- On app start (`Dependencies.init`), any draft with status `recording` or
  `paused` is marked `interrupted`; segments are checked: a zero-length last
  segment is dropped; a WAV segment gets its header repaired; the real
  duration of each segment is re-measured.

### Background and interruptions

- iOS: add `audio` to `UIBackgroundModes`; configure the audio session for
  play-and-record with Bluetooth and speaker defaults. Recording continues
  with the screen locked.
- Android: run recording in a foreground service of type `microphone`
  (via `flutter_foreground_task`, see above) with an ongoing notification "Recording a story · tap to return"
  (both languages) and Pause / Stop actions. Request notification permission
  on Android 13+ the first time the user records; if denied, recording still
  works in the foreground and the screen shows a one-line hint.
- Interruptions (phone call, Siri, another app takes the mic, headphones
  unplugged), detected through `onStopped()`'s `RecordStopReason`,
  `audioRouteChange: pause` and the iOS interruption mode: **auto-pause**, keep the draft, and show on return
  "Paused because a call came in. Tap to continue." Never auto-resume.
- Low storage: before starting and every 30 s, check free space; under
  50 MB, pause and show "Your phone is almost full. Free up space to keep
  recording." (`AppFailure.storageFull`, new).

### Continue after the app closed (artboard RecordResume)

- When the Record tab opens (and once on app launch, as a sheet over the
  current screen) and an `interrupted` draft exists, show the **Continue a
  recording** screen: title "Your recording with {narrator} is safe",
  when it stopped, total kept duration, segment bar, play button (plays all
  segments in order), and three actions: **Continue recording** (record
  button style, appends a new segment and returns to the live screen with
  the timer continuing from the kept duration), **It's finished, save it**
  (goes to the save/visibility screen), **Delete this recording**
  (destructive, asks once, plainly).
- Several interrupted drafts: list them newest first, same actions per row.
- Remove today's `AlertDialog` (`draftFoundTitle`) flow.

### Upload

`StoryEditScreen._save` (and spec 04's save flow) joins segments into one
file before upload: ADTS → byte concatenation to `<draft>/story.aac`, upload
with content type `audio/aac`; WAV → concatenate PCM and write one header.
The storage bucket already allows `audio/aac` and `audio/wav`. Storage path
stays `<space>/<uid>/<story>/a.<ext>`. Delete the local segments only after
the story row is created.

## Out of scope

Editing/trimming audio; noise reduction; cloud backup of unsaved drafts.

## Acceptance criteria

- **AC-1** Starting a recording writes a draft to the index before the first
  second of audio (unit test with a fake recorder + `FileDraftStore` in a temp dir).
- **AC-2** Segments rotate every 30 s and on every resume; durations add up
  to the recorded time ±0.5 s (unit test with a fake clock).
- **AC-3** Simulated kill: a draft left `recording` with a truncated last
  segment is recovered on start as `interrupted`, the truncated segment is
  kept if non-empty and its duration re-measured (unit test with a real
  truncated ADTS fixture and, if used, a truncated WAV fixture in `test/fixtures/`).
- **AC-4** Old single-file drafts still load (JSON backward-compat test).
- **AC-5** Interruption events pause the recorder and set the paused reason;
  nothing auto-resumes (unit test on the Notifier with a fake interruption stream).
- **AC-6** Continue-a-recording screen matches the artboard in light/dark ×
  en/ar, with widget tests for Continue, Save and Delete (with confirmation),
  and for the multi-draft list.
- **AC-7** Continue appends a segment and the timer continues from the kept
  duration (widget/unit test).
- **AC-8** Save joins segments into one playable file; the uploaded size
  equals the sum of segment sizes for ADTS (unit test of the joiner).
- **AC-9** iOS `Info.plist` has `UIBackgroundModes` `audio` and a clear
  `NSMicrophoneUsageDescription` in both languages (InfoPlist.strings);
  Android manifest declares the microphone foreground service and its
  permissions; `test/security/platform_config_test.dart` still passes and has
  new assertions for these entries.
- **AC-10** Storage-full and permission-denied states are designed and tested.
- **AC-11** Integration test (demo style): record 5 s, pause, resume, record
  5 s, simulate app restart by re-initialising the store, see the Continue
  screen, continue, finish, reach the save screen.
- **AC-12** `docs/features/recording.md` (new) documents segments, recovery,
  platform settings and the manual device test below; `store/play_app_content.json`
  notes the microphone foreground service.

## Manual device test (write the results in the PR)

On a real iPhone and a real Android phone: record 2 minutes with the screen
locked; take a phone call mid-recording; swipe the app away mid-recording
and reopen; turn on airplane mode and save (expect the offline state, then
upload when back online). Each must keep every second recorded before the
event.

## Analytics

`recording_started`, `recording_paused` {reason: user|interruption|storage},
`recording_resumed`, `recording_recovered` {segments, minutes_bucket},
`recording_discarded`, `recording_finished` {minutes_bucket}. No names or titles.
