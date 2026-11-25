# Before 0010/0011 reach production: live checks and backup

Read-only checks to run in the Supabase SQL editor of the production project, then a backup. Nothing here changes data. Paste the results back into the PR so the grants/RLS review uses the live state, not the migration files.

## 1. Which migrations are applied

```sql
select version, name from supabase_migrations.schema_migrations order by version;
```
Expected before this change: 0001 to 0009 only.

## 2. Table RLS and policies (public schema)

```sql
select c.relname, c.relrowsecurity as rls, c.relforcerowsecurity as forced
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r' order by 1;

select tablename, policyname, cmd, roles, qual, with_check
from pg_policies where schemaname = 'public' order by tablename, policyname;
```
Every app table should show `rls = true`. Compare the policy list with supabase/migrations/0004 and 0007.

## 3. Function definitions and who can run them

```sql
select p.proname, pg_get_function_identity_arguments(p.oid) as args,
       p.prosecdef as security_definer, p.proacl as acl
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('join_family_space', 'handle_new_user', 'create_family_space',
                    'generate_short_code', 'set_invite_short_code')
order by 1;
```
`join_family_space(uuid)` must still exist and stay executable by `authenticated` (the shipped app calls it). 0010 and 0011 replace `handle_new_user` and add new functions.

## 4. Table grants for the API roles

```sql
select table_name, grantee, string_agg(privilege_type, ', ' order by privilege_type) as privileges
from information_schema.role_table_grants
where table_schema = 'public' and grantee in ('anon', 'authenticated')
group by 1, 2 order by 1, 2;
```

## 5. The auth.users trigger and data size

```sql
select tgname, tgenabled from pg_trigger
where tgrelid = 'auth.users'::regclass and not tgisinternal;

select (select count(*) from public.family_spaces) as family_spaces,
       (select count(*) from public.family_members) as members,
       (select count(*) from public.profiles) as profiles;
```
0010 backfills one code per family space; the size tells how long the backfill runs.

## 6. Backup and recovery path

Official rules (https://supabase.com/docs/guides/platform/backups): daily backups exist for Pro, Team and Enterprise plans (Dashboard > Database > Backups); Point-in-Time Recovery is a paid add-on; free-tier projects should export with the CLI `db dump` and keep the file off-site. The plan of this project is not recorded anywhere in the repo, so read it from Dashboard > Settings > Billing and Dashboard > Database > Backups before deciding.

- If a daily backup from today exists: note its timestamp. Restore is a whole-project restore with downtime and loses newer data, so it is the last resort.
- If not (free plan): take a logical dump first: `supabase db dump --linked -f backup_before_0010.sql` and `supabase db dump --linked --data-only -f backup_before_0010_data.sql`, store both off the repo (the repo is public).
- Exact undo of the schema change if the data is fine: `supabase/rollback/0010_0011_rollback.sql` (tested in CI with 200 seeded families, see supabase/tests/upgrade_0010_0011.test.sql).

Only after sections 1 to 5 look as expected and a backup exists should #16 reach main, because the merge deploys supabase/** automatically (.github/workflows/supabase.yml).
