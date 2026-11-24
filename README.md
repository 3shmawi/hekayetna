# Hekayetna — Family Stories (حكايتنا)

Preserve family stories in the voices of the people who lived them.
Record a grandparent telling a story, add the people and photos it is about,
and choose exactly who in the family can listen. Arabic (RTL) and English,
private by default.

> Status: early development. Not on the stores yet.

## What it does

- **Stories feed**: the home screen. Filter by topic, narrator or person.
- **Record**: capture audio with pause/resume. Drafts stay on the device until
  you publish them.
- **Who can listen**: every story is *private*, shared with the *family*, or
  shared with *selected* members. New members don't get access to older
  stories, and removing a member takes their access away.
- **Family**: create a family space or join one with an invite code, build the
  family tree, and link people to stories and photos.
- **Photos**: upload, caption and tag family photos.
- **Accounts**: email + password sign-in, with in-app account deletion.
- **Demo mode**: runs without a backend, using sample data, with a clear
  "demo" label.

## Stack

Flutter (version pinned in `.fvmrc`) · Riverpod · go_router · Supabase
(Postgres + RLS, Auth, Storage) · PostHog · `record` + `just_audio` ·
Material on Android, Cupertino on iOS · Inter + Cairo fonts · GitHub Actions CI/CD.

Generated with flutter-project-kit; see [`CLAUDE.md`](CLAUDE.md) for the rules
every change follows.

## Getting started

```bash
cp env/example.json env/dev.json   # fill in the publishable keys (leave empty for demo mode)
./scripts/run.sh dev
```

Full setup (env files, Supabase, simulators): [docs/getting_started.md](docs/getting_started.md).

## Everyday commands

```bash
flutter test                 # unit + widget + golden + security tests
flutter analyze              # must be clean
dart format .
flutter gen-l10n             # after editing lib/l10n/*.arb
```

## Project layout

```
lib/features/   auth · onboarding · stories · recording · family · photos · settings
lib/core/       router, theme, adaptive UI, backend, analytics, network
supabase/       migrations (RLS on every table) + pgTAP access tests
docs/           features, designs, backend, security, release
```

## Docs

- [Documentation index](docs/README.md)
- [Backend & access rules](docs/backend.md)
- [Security](docs/security.md)
- [Release & CI/CD](docs/release.md): merging to `main` releases to both stores

## Privacy

Stories are private by default. Access is enforced in the database with
row-level security and short-lived signed URLs for audio and photos, not only
in the app. Only publishable keys ship in the app binary.
