# Designs

Approved specs for big features, one file per feature:
`docs/designs/<feature>.md`. Each one is drafted with `/egm:egm-draft`,
reviewed with `/egm:egm-review` and approved before any code is written
(`CLAUDE.md` → "Design before code for big features").

Keep a spec as the record of what was decided and why. When the feature
changes later, update its `docs/features/<feature>.md`; run
`/egm:egm-drift-report` to find docs that no longer match the code.

## Build plan (in order)

Start with [the implementation guide](00-implementation-guide.md); every
spec relies on it. One spec per pull request, in this order.

| # | Spec | Depends on | Notes |
|---|---|---|---|
| 01 | [Design foundation](01-design-foundation.md) | none | tokens, theme, shared widgets, tab bar |
| 02 | [Recording that survives anything](02-recording-recovery.md) | 01 | data-loss fix; platform settings |
| 03 | [Stories feed, story page, player](03-stories-and-player.md) | 01 | repositories move to `Result` |
| 04 | [Record screen and "who can listen"](04-record-and-share.md) | 01–03 | migration 0008 |
| 05 | [Family tree graph and person sheet](05-family-tree.md) | 01, 03 | migration 0009 |
| 06 | [Invite (WhatsApp, QR, code) and display names](06-invite-and-profile.md) | 01, 03 | migration 0010, new route |
| 07 | [Interview prompts](07-interview-prompts.md) | 01, 03, 04 | migration 0011 |
| 08 | [Elder mode](08-elder-mode.md) | 01–04, 07 | new route |
| 09 | [Remembrance](09-remembrance.md) | 01, 03, 05 | migration 0012 |
| 10 | [Transcripts](10-transcripts.md) | 01, 03 | **blocked on owner decisions** |

Builder start message: [BUILDER_START.md](BUILDER_START.md).

These specs were written in Claude Code without the EGM plugin loaded (no
goldfish review); the owner reviews and approves each one by merging the PR
that adds it.
