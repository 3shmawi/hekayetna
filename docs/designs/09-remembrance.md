<!-- Sensitive feature: owner review required on tone and copy. -->

# Spec 09 · Remembrance

Status: ready for review · PR title: `feat: remembrance page and anniversary card for family who passed`
Branch: `feat/09-remembrance` · Depends on: 01, 03, 05 · Flag: `remembrance`

## Why

For many families the most precious recordings are of someone who has died.
Their page should feel calm and respectful, make their voice one tap away,
and gently bring the family back on the anniversary.

## Design references

- Remembrance page: `#artboard-IdeaRemembrance` (page "Ideas", dark)
- Design System: Button, StoryCard row style, PersonChip

## Code to read first

`lib/features/family/**` (person detail, spec 05 person sheet),
`supabase/migrations/0003_family_schema.sql` (`persons.approx_death_date`).

## Scope

### 1. Data: migration `0012_person_death_date.sql`

- `persons.death_date date` (nullable, exact date when known; the existing
  free-text `approx_death_date` stays for "about 2019"). Edit person gets
  "Date of passing (optional)" with a date picker and the free-text field.
- `memories` are ordinary stories: a story **about** a person (in
  `story_people`) whose narrator is someone else. No new table.
- pgTAP: same access as other person columns.

### 2. Remembrance page (`RemembrancePage`), per artboard

- Shown instead of the normal person page/sheet header for a person with a
  death date or approximate death date (person sheet "See their page"
  opens it; the tree node shows the person normally, no special marks).
- Large photo (148 px circle with a 2 px ring and sand gap), name
  (`display`), "1934 – 2021 · Shubra", and in Arabic the line "الله يرحمه" /
  "الله يرحمها" by gender (English shows nothing extra). The owner may turn
  the Arabic line off per person (some families prefer not): a switch in
  edit person, default on.
- **Anniversary card** (only from 3 days before to 3 days after the date of
  passing each year, and only when `death_date` is exact): moon icon, "Today,
  5 years ago" (or "This week, 5 years ago"), "The family is listening to
  Giddu today. Hear his voice, or add a memory of him.", **Play his voice**
  (queues his stories, spec 05 queue) and **Add a memory** (opens Record
  with the narrator = me and Giddu added to "people in this story", topic
  "memories").
- Outside the anniversary window the card shows only the two buttons.
- **In his own voice · 9**: his narrated stories (3, then See all).
- **Memories from the family**: stories about him by others, with the
  narrator's avatar.
- The page follows the app's theme like every other screen; the artboard
  is drawn in dark only to show it works there.

### 3. Anniversary reminder

In-app only in this spec: on the anniversary day, the feed shows the same
card at the top for members who can hear at least one of his stories.
(Push reminders come with the push module.)

## Acceptance criteria

- **AC-1** Migration 0012 + pgTAP; date picker and switch in edit person.
- **AC-2** Page matches the artboard (goldens light/dark × en/ar, male and
  female, with and without photo).
- **AC-3** Anniversary window logic unit-tested (leap years, Feb 29 → Feb 28,
  time zones: use the device's local date).
- **AC-4** Play his voice queues only stories the user can access.
- **AC-5** Add a memory pre-fills narrator, person and topic.
- **AC-6** Feed card appears only in the window and only for members with
  access.
- **AC-7** Arabic line follows gender and the per-person switch.
- **AC-8** Integration test (demo style): open Giddu from the tree, see his
  page, play his voice, add a memory.
- **AC-9** `docs/features/remembrance.md` includes the copy for owner review.

## Analytics

`remembrance_opened`, `remembrance_played`, `memory_recorded`,
`anniversary_card_shown`. Never names or dates.
