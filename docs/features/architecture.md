# Flutter architecture

Status: design + implementation in progress. What exists is reported honestly
in the README checklist; nothing is called complete before it is implemented
and tested.

## Stack decisions (verified 2026-11-23 on pub.dev)

| Package | Version checked | Why |
|---|---|---|
| supabase_flutter | 2.18.3 | Auth, Postgres, Storage in one client |
| flutter_riverpod | 3.5.0 | State management + DI, compile-safe |
| go_router | 18.1.4 | Declarative navigation, deep links |
| record | 7.2.0 | Audio capture with pause/resume |
| just_audio | 0.10.6 | Playback with position streams |
| image_picker | 1.2.4 | Photo capture/library |
| path_provider | 2.1.6 | On-device draft storage |

Rejected: hive_flutter (unmaintained since 2021), freezed (codegen friction the
MVP does not need; models are hand-written with fromJson/toJson).

## Structure

Feature-first modules, each with `presentation/`, `domain/`, `data/`:

```
lib/
  main.dart                 # bootstrap: env config, Supabase init (when configured)
  app.dart                  # MaterialApp.router, theme, locale
  core/
    config/                 # EnvConfig from --dart-define; never hardcoded secrets
    theme/                  # warm design tokens, elder-accessible text scale
    l10n/                   # AppStrings: en + ar maps, RTL via flutter_localizations
    router/                 # go_router, auth redirect
  features/
    auth/                   # magic-link sign-in
    family/                 # create/join space, members
    people/                 # directory, person detail, relationships
    recording/              # capture, pause/resume, preview, drafts
    stories/                # feed, detail, create/edit, visibility
    photos/                 # upload, captions, tagging, linking
    settings/
```

Repository pattern per feature: a domain interface, a Supabase implementation,
and an in-memory demo implementation. `EnvConfig` selects which one the
providers hand out. **Demo mode is clearly labeled in the UI** and exists only
when no Supabase URL is configured; it is never presented as a real backend.

## Configuration

```
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

The anon key is client-safe by design (RLS is the enforcement layer), but it
is still collected through the vault flow and injected at build/run time,
never committed. Missing config → demo mode, loudly labeled.

## Recording pipeline

1. `AudioRecorderService` (interface) wraps `record`. States: idle, recording,
   paused, stopped, error. Phone-call interruptions move to `paused` and keep
   the partial file.
2. Every take writes to the app documents directory immediately; a JSON index
   (`DraftStore`) tracks draft id, path, narrator, topic, duration, updated
   time. A draft survives process death by construction.
3. Preview uses `just_audio` on the local file. Re-record deletes the file and
   index entry. Saving a story uploads the file to `story-audio` and only then
   creates the `stories` row; upload failure keeps the draft intact with a
   visible retry state.
4. Device/OS limits (force-stop mid-write, OS reclaiming app storage,
   microphone permission revocation) are **not claimed as handled** until
   verified on real devices; they are listed in the test plan.

## Error handling

Repositories return typed results (`AppException` hierarchy: network,
permission-denied, not-found, conflict). The UI maps them to calm, non
technical messages in both languages, always with a retry path. No silent
failures, no fake success.

## Testing strategy

- Unit: draft store, visibility/access mirror logic, models, recording state
  machine (fake recorder), Arabic/English string coverage.
- Widget: sign-in, story feed (empty/loaded), recording controls, RTL layout.
- Backend: `supabase/tests/rls_access_tests.sql` (15 scenario groups incl.
  snapshot, removal, rejoin, re-share, self-grant, storage objects). These run
  against local Supabase; they have **not run yet** (no Docker in the build
  environment), which is why no live security claim is made.
