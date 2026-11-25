# Backend — Supabase

Postgres with row-level security (RLS), Auth, Storage and Edge Functions.
The app talks to it through `lib/core/backend/backend.dart` (`Backend.client`),
only from feature `data/` sources. Errors are mapped to `AppFailure` in
`lib/core/backend/backend_errors.dart`.

## Env keys (`env/<name>.json`)
| Key | Where to find it |
|---|---|
| `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` | Filled by `tool/setup_secrets.sh` when `SUPABASE_ADMIN_TOKEN` + `SUPABASE_ORG` are set (it creates the project); by hand: Supabase → Project settings → API Keys (`sb_publishable_…`) |

The publishable key is safe in the app *only because* every table has RLS.

## Credentials
| Name | Where it lives | Used by |
|---|---|---|
| `SUPABASE_ADMIN_TOKEN`, `SUPABASE_ORG` | `~/.app-secrets/shared.env` — never leaves your Mac | `tool/supabase_project.py` creates the project |
| `SUPABASE_ACCESS_TOKEN` | shared.env → GitHub secret | Supabase deploy (`supabase link` / `db push`) |
| `SUPABASE_DB_PASSWORD` | apps/<repo>/app.env → GitHub secret | Supabase deploy |
| `SUPABASE_SECRET_KEY` (`sb_secret_…`) | apps/<repo>/app.env → GitHub secret | Announce update — never in `env/*.json` |

## Deploys
Changes under `supabase/` merged to `main` → `.github/workflows/supabase.yml`
runs `supabase db push` (migrations) and deploys Edge Functions (when
`supabase/functions/` exists). The project ref is read from `SUPABASE_URL` in
`ENV_PROD_JSON`. First time: Actions → **Supabase deploy** → Run workflow
(`gh workflow run supabase.yml`). By hand instead: run
`supabase/migrations/0001_app_versions.sql` in Supabase → SQL editor (or
`supabase db push`). Then fix the iOS `store_url` once the App Store id exists.
Keep migrations backward compatible: the live app keeps running while the
store review of the new version is pending.

**Keep-alive:** free Supabase projects pause after 7 days without activity.
`.github/workflows/supabase-keepalive.yml` pings the `app_versions` table every
3 days using `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY` from the
`ENV_PROD_JSON` secret (Actions → *Supabase keep-alive* → Run workflow to test
it). GitHub pauses scheduled workflows in repos with no commits for 60 days —
re-enable it from the Actions tab if that happens.

## Before inviting family: profile names (migration 0011)
Since migration 0003, every new profile took the part of the email address
before the `@` as its name, and the family member list shows names to the
whole family. Migration `0011_profile_names.sql` stops that for **new**
profiles (they get a name only when the person chooses one; the list shows
"Family member" until then). It deliberately does **not** rewrite existing
profile rows, and the pgTAP tests passing does not mean old rows are clean.

Conditional release check, for the project owner only:
- If this Supabase project has had sign-ups since migration 0003 was applied,
  look at the displayed names privately (Supabase dashboard, `profiles`
  table) and decide whether each one is intended before inviting family.
  Change any you do not want shown with the owner's own authority.
- If no one has signed up since 0003, there is nothing to fix.
No live profile was inspected and no name was cleared while building this
change; whether any real account is affected is unknown.

## Rules
- Every table has RLS enabled; schema changes go in a new file in
  `supabase/migrations/` (never edit an applied migration).
- Every new table gets `supabase/tests/<table>_rls.test.sql` (pgTAP) proving
  what `anon` and `authenticated` can and can't do. CI runs
  `supabase test db` when a PR touches `supabase/` (`supabase/config.toml`
  is committed, so this is on). Locally: `supabase db start && supabase test db`
  (needs Docker).
- Rows that belong to a person go with their account (`on delete cascade`);
  shared family data uses `on delete set null`. A foreign key to `profiles`
  or `auth.users` without one of these blocks account deletion.
- Server secrets live in Edge Function secrets / Vault, never in the app.
