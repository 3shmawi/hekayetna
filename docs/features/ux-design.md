# UI/UX design

Direction from the spec: warm, human, calm, elegant, timeless. Arabic RTL and
English are equal citizens. Older users are first-class: large text, large
targets, predictable navigation.

## Design tokens

| Token | Value | Use |
|---|---|---|
| sand | #F6F1E7 | app background |
| surface | #FFFFFF | cards, sheets |
| ink | #25211D | primary text |
| ink-soft | #5F6B62 | secondary text |
| olive | #3F6B5C | primary actions, seed color (Mohamed-approved 2026-11-24) |
| terracotta | #9C4A21 | warm accents, record button |
| olive-teal | #4F7A6E | known/confirmed states, links |
| gold | #C9A227 | small warm accents only |
| error | #B3261E | destructive, errors |

Typography: system serif for display headings (warmth), system sans for body.
Base body 17sp, minimum 15sp, headings 22/28sp. Touch targets >= 48dp.
Contrast: all text/background pairs pass WCAG AA at these sizes.

Motion: only to explain state (record button breathing while recording, sheet
transitions). `MediaQuery.disableAnimations` honored: no breathing, no parallax.

## Strings live in both languages

Every screen ships `en` + `ar` at once. Arabic uses natural Egyptian-flavored
MSA: "سجل حكاية" (record a story), "مين يسمع دي؟" for who can listen, "العيلة"
for the family space. RTL is automatic via locale; all layouts are built with
EdgeInsetsDirectional/AlignmentDirectional and verified in a widget test.

## Navigation

Three primary destinations, bottom navigation, always visible:

1. **Stories** (الحكايات) — the home. Never the family map.
2. **Record** (سجل) — center, prominent, terracotta.
3. **Family** (العيلة) — people directory and relationships.

## The 14 screens

1. **Onboarding** — 3 skippable cards: preserve voices, connect photos and
   people, private by default. Then: create a family space or join with an
   invite code. Nothing else is required to reach the record button.
2. **Authentication** — email + magic link. One field, one button. Clear
   "check your email" state with resend. No passwords for elders to forget.
3. **Family home** — space name, member chips, invite-code sharing, stories
   preview. Joined state shows whose person record is linked to you.
4. **Story feed** — cards: title, narrator name(s), approx date, duration,
   topic tag. Filter row: recent, narrator, topic, person, period. Every card
   already filtered server-side by access. Empty state: "No stories yet.
   Record the first one." with a single button.
5. **Story details** — large play button, progress, narrator(s) with avatars,
   people mentioned, photos strip, approx date, description. "Who can hear
   this" row visible to the creator. Edit for creator only.
6. **Audio recording** — one huge record/pause button, timer, waveform state
   text ("Recording", "Paused"), narrator selector at top ("Speaking: Sitto"),
   topic chip row (optional). Interrupt-safe: leaving keeps the draft.
7. **Recording preview** — play/pause, position slider, duration. Three calm
   actions: save, re-record, delete. No accidental-loss paths: delete asks
   once, plainly.
8. **Story create/edit** — title, optional description, narrators
   (multi-select people), people mentioned, approx date (free text +
   optional year), photos, topic, and the visibility picker below.
9. **Photo selection** — grid of existing photos plus "add new". Multi-select
   for stories.
10. **People directory** — searchable list, avatar, name, approx dates.
    "Add a person" needs only a name. No account required, ever.
11. **Person details** — photo, name, dates, bio, their stories (narrated and
    mentioned, access-filtered), relationships grouped by type with
    pending/confirmed badges.
12. **Relationships** — add relationship: pick person, type
    (parent/child/spouse/sibling), other person. Pending until the other side
    (or the owner) confirms. No automatic inference anywhere.
13. **Privacy settings** — per story: Private / Selected people (member
    picker) / Whole family. A plain sentence always shows the consequence:
    "Only you can hear this", "3 people can hear this: …", "Everyone in
    Ashmawy family as of today; people who join later won't".
14. **Profile/settings** — display name, language (EN/AR toggle), your linked
    person record, sign out, leave family space (with its consequences in
    plain words).

## Guided topics (record screen, optional)

childhood_first_home, parents_grandparents, how_parents_met,
weddings_beginnings, ramadan_eid_traditions, life_events, funny_memories,
lessons_for_future. "No topic" is always valid and never blocks saving.

## States

Every list has designed empty, loading, and error states with a retry.
Recording has explicit states for permission denied (with a path to system
settings) and interruption recovery ("You have an unfinished recording —
continue where you left off?").

## What is deliberately absent

No feed algorithm, no likes, no counts, no streaks, no badges. The map is a
list. The reward is the story itself.
