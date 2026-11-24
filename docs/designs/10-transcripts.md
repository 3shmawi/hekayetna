<!-- BLOCKED until the owner records the decisions in section "Owner decisions". -->

# Spec 10 · Transcripts while listening

Status: **blocked on owner decisions** · PR title: `feat: transcripts that follow the story while it plays`
Branch: `feat/10-transcripts` · Depends on: 01, 03 · Flag: `transcripts`

## Why

Words on screen help relatives who are hard of hearing, let people read a
story silently, and make every story searchable ("Shubra", "railway").

## Owner decisions (must be filled before any code)

1. **Speech-to-text provider** (Egyptian Arabic quality matters most):
   candidates to evaluate on 5 real family recordings, with cost per hour
   and data-retention terms checked in their current docs. The owner picks
   one and writes it here.
2. **Consent**: transcription sends a story's audio to that provider. Default
   proposed: off per family; the family owner turns it on in settings with a
   plain explanation; each story's creator can opt a story out.
3. **Translation** (the "English" tab in the artboard): in or out of the
   first version.
4. **Budget**: monthly cap; what happens when it is reached (queue until
   next month).

Until these are written here, the builder does not start this spec.

## Design references

- Story with transcript: `#artboard-IdeaTranscript` (page "Ideas")

## Scope (once unblocked)

### 1. Backend

- Migration `0013_transcripts.sql`: table `story_transcripts(story_id uuid
  primary key references stories on delete cascade, language text, status
  text check (status in ('queued','processing','ready','failed')),
  segments jsonb, -- [{startMs, endMs, text}]
  translation jsonb, created_at, updated_at)`. RLS: select exactly when
  `can_access_story(story_id)`; no client insert/update/delete (service role
  only). pgTAP for member, non-member, removed member, anon.
- `family_spaces.transcription_enabled boolean not null default false`
  (owner can update; pgTAP).
- Edge Function `transcribe-story` (service role): triggered after a story is
  created in a family with transcription on; downloads the audio with the
  service key, calls the provider, writes segments; retries with backoff;
  never logs audio, text or user ids. Provider key in Supabase function
  secrets only. Deployed by the existing workflow.
- Full-text search: a generated `tsvector` column over the segment text
  (`simple` config for Arabic) with a GIN index, queried only through an RPC
  that applies `can_access_story`.

### 2. App

- Story page: a **Words** button opens the transcript view (artboard):
  segmented control Words / English (English only if translation is on),
  search in this story, lines with timestamps, the current line highlighted
  in `primaryContainer` and kept in view while playing, tap a line to seek.
  Arabic lines are RTL with Cairo at 20/36. Mini player at the bottom.
- States: queued/processing ("Words will appear in a few minutes"), failed
  ("We couldn't turn this story into words." + Try again for the creator),
  disabled for the family (the button doesn't show).
- Settings (owner): "Show the words of each story" switch with the consent
  text from decision 2.
- Search in the feed (spec 03's search button) searches transcripts through
  the RPC when enabled.

## Acceptance criteria (once unblocked)

- **AC-1** Migration + RLS + pgTAP; no client can write transcripts.
- **AC-2** Edge Function tested with a fake provider (unit) and a recorded
  fixture; no personal data in logs.
- **AC-3** Transcript view matches the artboard; current-line tracking and
  tap-to-seek tested with a fake player clock.
- **AC-4** All states designed and tested; feature flag and family setting
  both gate it.
- **AC-5** Privacy policy (`website/`), `store/play_app_content.json`
  (data shared with a processor) and `docs/security.md` updated.
- **AC-6** `docs/features/transcripts.md` with provider, costs, retention.

## Analytics

`transcript_opened`, `transcript_line_tapped`, `transcript_search`
{results_bucket}, `transcription_enabled_changed`.
