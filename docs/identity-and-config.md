# App identity and generator configuration: what is real and what is provisional

The project was generated with Mohamed's flutter-project-kit. The kit reads
`~/.flutter-kit/kit.conf` at generation time. This file records where each
value came from so nobody mistakes a generator default for an approved
production identity.

## Values grounded in Mohamed's own context

| Value | Source |
| --- | --- |
| Org `com.mohager` (bundle id `com.mohager.hekayetna`) | Mohamed chose `com.mohager.<app>` on 2026-11-24 |
| GitHub owner `3shmawi` | His kit repository (github.com/3shmawi/flutter-project-kit) |
| Developer name "Mohamed Ashmawy" (store/ios/copyright.txt) | His name |
| Fonts Inter (Latin) + Cairo (Arabic) | Kit defaults; also the right pairing for an Arabic-first app |

## Provisional values chosen during generation (NOT approved disclosures)

| Value | Where it lives | Status |
| --- | --- | --- |
| Support email `mohamedashmawy918@gmail.com` | store/play_app_content.json only (Play data-safety answers). Not shown in the app UI. | Provisional. Publishing it as a public support contact is Mohamed's decision; swap or confirm before any store submission. |
| Primary color `#3F6B5C` (olive), accent `#9C4A21` (terracotta) | Theme | CONFIRMED by Mohamed 2026-11-24 (olive-tree/family-gathering identity, palette B from the delivered study). |
| App name "Hekayetna" / "حكايتنا", package `com.mohager.hekayetna` | ARB `appTitle`, flavorizr, bundle IDs | CONFIRMED by Mohamed 2026-11-24. Deep-link scheme remains `familystories://` pending his decision to rename it (his Supabase redirect config references it). |
| Apple Team ID (empty), Codemagic integration name | kit.conf | Placeholders; no Apple or CI resources were created. |

## External resources

None were created. No Supabase project, no Apple/Google developer
resources, no push to any remote. The local git history is the only copy
besides the handoff archive. Creating any of these needs Mohamed's go-ahead.
