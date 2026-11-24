# Spec 07 · Interview prompts ("Questions to ask")

Status: ready for review · PR title: `feat: questions to ask, with follow-ups and progress`
Branch: `feat/07-interview-prompts` · Depends on: 01, 03, 04 · Flag: `interview_prompts`

## Why

Most people don't know what to ask their grandmother. A good question is
the difference between "I don't remember" and a 10-minute story.

## Design references

- Questions to ask: `#artboard-IdeaPrompts` (page "Ideas")
- Question of the week card on the feed: `#artboard-Main`, `#artboard-FeedArDark`
- Prompt card on the recording screen: `#artboard-Record`, `#artboard-RecordArDark`

## Code to read first

`lib/features/stories/domain/story_topics.dart`, the recording and save
screens from spec 04, the feed from spec 03.

## Scope

### 1. The question library (content, not backend)

- `assets/prompts/prompts.json`, versioned (`"version": 1`), loaded once and
  cached. Each prompt: `id` (stable, e.g. `childhood_street`), `topic` (a key
  from `story_topics.dart`), `en` and `ar` question text, up to two
  follow-ups per language, and `audience`: `any | elder`.
- At least **12 prompts per topic** for the existing topics. The Arabic is
  natural Egyptian Arabic (like the artboard: "كانت أمك بتطبخ إيه في
  رمضان؟"), written as a person asks, not translated literally. The PR lists
  all prompts in a table for the owner to review; the owner may edit the
  JSON in review.
- A test validates the file: unique ids, known topics, both languages
  present, no empty strings, lengths ≤ 140.

### 2. Answered questions (backend)

Migration `0011_story_prompt.sql`: `stories.prompt_id text` (nullable, ≤ 64,
`^[a-z0-9_]+$`). Saving a story started from a prompt stores it. "Answered"
= a story the user can access with that `prompt_id` and that narrator.
pgTAP: unchanged access; check constraint rejects junk.

### 3. Questions to ask screen (`PromptsPage`), per artboard IdeaPrompts

- Entry: a "Questions to ask" row on the Record tab's empty start state, a
  link on the question card in the feed ("More questions"), and the person
  sheet when the person has no stories.
- **Asking** chips: family people who can tell stories (elders first: those
  with the most stories, then by birth year). Selecting one personalises
  "Ask Sitto" / "اسأل ستو".
- Topic filter chips (never wrap, scroll horizontally).
- Progress "3 of 12 answered" + bar, for the selected person and topic.
- **Surprise me**: scrolls to and highlights a random unanswered question.
- Question cards: question (`title`), follow-ups line, **Ask {name}**
  (record colour) → opens Record with narrator, topic and prompt set, and a
  **Save for later** bookmark (stored locally in `SharedPreferences`, list
  of prompt ids; saved ones sort first).
- Answered card (tint background): "Answered · {story title}" + **Listen**.

### 4. Question of the week (feed card, artboard Main)

- On the feed, above "Recently added": the week's question for the person
  most likely to answer (an elder with stories, not yet asked this prompt),
  chosen deterministically from the ISO week number so everyone in the
  family sees the same one that week. Button **Record his/her answer** opens
  Record prefilled. "More questions" opens the library. Dismiss (×) hides it
  until next week (local).

### 5. Recording screen prompt card

Spec 04's prompt card shows the chosen prompt and its follow-ups; "Different
question" picks the next unanswered prompt in the same topic.

## Out of scope

Push notifications for the weekly question (needs the push module: a
separate spec after this one).

## Acceptance criteria

- **AC-1** `prompts.json` valid (test), ≥ 12 per topic, table in the PR.
- **AC-2** Migration 0011 + pgTAP; `prompt_id` saved when recording from a prompt.
- **AC-3** Prompts screen matches the artboard (goldens light/dark × en/ar).
- **AC-4** Asking/topic chips, Surprise me, Save for later and answered
  cards behave as specified (widget tests).
- **AC-5** Question of the week is the same for every member in the same
  ISO week and changes next week (unit test with a fixed clock); dismiss
  hides it for the week.
- **AC-6** Ask {name} opens Record with narrator, topic and prompt set.
- **AC-7** Feature flag off hides every entry point.
- **AC-8** Integration test (demo style): feed → question of the week →
  record → save → the question shows as answered.
- **AC-9** `docs/features/prompts.md`.

## Analytics

`prompts_opened` {from}, `prompt_asked` {topic}, `prompt_saved_for_later`,
`prompt_surprise_me`, `weekly_prompt_shown`, `weekly_prompt_dismissed`,
`weekly_prompt_recorded`. Never the prompt text.
