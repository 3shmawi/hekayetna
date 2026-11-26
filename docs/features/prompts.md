# Questions to ask (spec 07)

Status: Part A (no backend) is built behind the `interview_prompts` flag, which is off in every flavor. Part B (`prompt_id` on stories, answered state, AC-2 and AC-8) is not built: it needs a migration and waits for the migration gate.

## What is there

- `assets/prompts/prompts.json` (version 1): 96 prompts, 12 for each of the 8 topics, English and Egyptian Arabic, up to two follow-ups, audience `any` or `elder`. Only one question comes from the spec; the rest are newly written and the Arabic is unreviewed. The full table is in `prompts-review.md` for the owner to edit.
- `PromptsPage` at `/prompts`: Asking chips, topic chips, "N of M answered" with a bar, Surprise me, question cards, Ask {name}, Save for later (device only, `SharedPreferences`).
- Question of the week: `WeeklyPromptCard` fills the feed's existing `questionSlot`. The question comes from the ISO week (`weeklyPrompt`, FNV-1a hash), so every member sees the same one all week. It is asked of the relative with the most stories. The close button hides it until next week (stored on the device).
- Ask {name} and the week card's Record button open `/record?topic=..&prompt=..` after setting the narrator. The Record screen shows that question in its prompt card when the flag is on.
- Entry points, all hidden when the flag is off: the feed card ("More questions"), a "Questions to ask" link on Record before a take starts, and the person sheet when the person has no stories.
- Analytics (never the question text): `prompt_asked {topic}`, `prompt_saved_for_later`, `prompt_surprise_me`, `weekly_prompt_shown`, `weekly_prompt_dismissed`, `weekly_prompt_recorded`. `prompts_opened {from}` is not sent yet.

## Not done

- "Answered" state: `answeredPromptsProvider` returns nothing until `stories.prompt_id` exists. The migration number in the spec (`0011_story_prompt`) is stale: 0011 is `0011_profile_names` on the invite branch. It takes the next free number after that branch lands.
- "Different question" on Record still cycles the four starter questions; picking the next unanswered prompt of the topic (`nextUnanswered` exists and is tested) waits for the answered state.
- AC-8 integration test.

## Tests

`test/features/prompts/` (library, logic, page, week card), `record_view_test.dart` and `person_sheet_test.dart` (entry points), goldens in `test/golden/prompts_golden_test.dart`, real-font screenshots in `test/screenshot/prompts_shots_test.dart`. The Arabic strings are unreviewed.
