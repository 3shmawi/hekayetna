-- Upgrade regression for migrations 0010_invite_codes and 0011_profile_names.
-- Run in CI:  supabase test db   (throwaway local database, never production)
--
-- What it proves, in one transaction that is rolled back at the end:
--   1. Rollback: the documented rollback (supabase/rollback/0010_0011_rollback.sql,
--      copied inline below, keep both in sync) returns the database to the
--      0009 shape, with the 0003 handle_new_user restored.
--   2. Seeded data: families, members and profiles created in that pre-0010
--      shape get a valid, unique short code when 0010 is re-applied, and the
--      old UUID join and the old insert path (no code supplied) keep working.
--   3. Prior behaviour: join_family_space(uuid) is byte-identical before and after.
--   4. 0011: existing display names are not rewritten; a new user without a
--      name gets NULL (not the email prefix); a chosen name is trimmed to 40.
--   5. Rollback with data present keeps the families and the old join working.
--   6. Collision atomicity: when the unique index step fails (forced duplicate
--      codes), every statement of 0010 is undone, no partial column or function.
--
-- The migration text is read back from supabase_migrations.schema_migrations
-- (the CLI records the exact statements it applied), so this tests the real
-- files, not a copy. Limit: it covers a local database, not the production
-- project's own data, grants or plan.

begin;

create schema if not exists extensions;
do $setup$
begin
  if exists (select 1 from pg_available_extensions where name = 'pgtap') then
    execute 'create extension if not exists pgtap with schema extensions';
  else
    execute $f$create or replace function extensions.plan(n integer)
      returns void language plpgsql as $b$ begin end $b$$f$;
    execute $f$create or replace function extensions.ok(cond boolean, msg text)
      returns void language plpgsql as $b$
      begin
        if not coalesce(cond, false) then
          raise exception 'not ok - %', msg;
        end if;
      end $b$$f$;
    execute $f$create or replace function extensions.finish()
      returns setof text language sql as $b$ select null::text where false $b$$f$;
  end if;
end $setup$;

select extensions.plan(1);

create or replace function pg_temp._assert(p_cond boolean, p_msg text)
returns void language plpgsql as $$
begin
  if not coalesce(p_cond, false) then
    raise exception 'UPGRADE TEST FAILED: %', p_msg;
  end if;
end $$;

-- Apply the recorded statements of one migration. p_hook, when given, is a
-- statement run right after the statement that creates generate_short_code.
create or replace function pg_temp._apply(p_version text, p_hook text default null)
returns void language plpgsql as $$
declare
  v_stmts text[];
  v_stmt text;
begin
  select statements into v_stmts
  from supabase_migrations.schema_migrations where version = p_version;
  if v_stmts is null then
    raise exception 'UPGRADE TEST FAILED: no recorded statements for migration %', p_version;
  end if;
  foreach v_stmt in array v_stmts loop
    execute v_stmt;
    if p_hook is not null and v_stmt ilike '%function public.generate_short_code%' then
      execute p_hook;
    end if;
  end loop;
end $$;

-- The documented rollback. Keep in sync with supabase/rollback/0010_0011_rollback.sql.
create or replace function pg_temp._rollback()
returns void language plpgsql as $$
begin
  drop function if exists public.set_my_display_name(text);
  create or replace function public.handle_new_user()
  returns trigger language plpgsql security definer set search_path = ''
  as $f$
  begin
    insert into public.profiles (id, display_name)
    values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1)))
    on conflict (id) do nothing;
    return new;
  end;
  $f$;
  revoke execute on function public.handle_new_user() from public, anon, authenticated;

  drop function if exists public.rotate_invite_code(uuid);
  drop function if exists public.preview_family_by_code(text);
  drop function if exists public.join_family_space_by_code(text);
  drop function if exists public.normalize_invite_code(text);
  drop trigger if exists family_spaces_short_code on public.family_spaces;
  drop function if exists public.set_invite_short_code();
  alter table public.family_spaces drop constraint if exists family_spaces_invite_short_code_format;
  drop index if exists public.family_spaces_invite_short_code_key;
  alter table public.family_spaces drop column if exists invite_short_code;
  drop function if exists public.generate_short_code();
end $$;

create temp table _state (key text primary key, val text);
grant all on _state to authenticated, anon;

-- 3 (before). Fingerprint of the old UUID join.
insert into _state values ('join_md5',
  md5(pg_get_functiondef('public.join_family_space(uuid)'::regprocedure)));

-- 1. Roll back to the 0009 shape.
select pg_temp._rollback();
select pg_temp._assert(
  not exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'family_spaces'
                and column_name = 'invite_short_code'),
  'rollback must remove invite_short_code');
select pg_temp._assert(
  to_regprocedure('public.join_family_space_by_code(text)') is null
  and to_regprocedure('public.rotate_invite_code(uuid)') is null
  and to_regprocedure('public.generate_short_code()') is null,
  'rollback must remove the 0010 functions');

-- 2. Seed data in the pre-0010 shape.
insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_user_meta_data) values
  ('b1111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'old.owner@test.local', '', now(), now(), now(), '{"display_name":"Old Owner"}'),
  ('b2222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'old.joiner@test.local', '', now(), now(), now(), '{}');
-- Pre-0011 behaviour: a user without a name got the email prefix.
select pg_temp._assert(
  (select display_name from public.profiles where id = 'b2222222-2222-2222-2222-222222222222') = 'old.joiner',
  'before 0011 the email prefix is used as the name');

insert into public.family_spaces (name, created_by)
select 'Seed family ' || g, 'b1111111-1111-1111-1111-111111111111'
from generate_series(1, 200) g;
insert into public.family_memberships (space_id, user_id, role)
select id, 'b1111111-1111-1111-1111-111111111111', 'owner' from public.family_spaces
where name like 'Seed family %';
insert into _state values ('old_uuid',
  (select invite_code::text from public.family_spaces where name = 'Seed family 1'));

-- Apply 0010 and 0011 to that data.
select pg_temp._apply('0010');
select pg_temp._apply('0011');

select pg_temp._assert(
  (select count(*) from public.family_spaces where name like 'Seed family %' and invite_short_code is null) = 0,
  'every seeded family must get a short code');
select pg_temp._assert(
  (select count(distinct invite_short_code) from public.family_spaces where name like 'Seed family %') = 200,
  'seeded short codes must be unique');
select pg_temp._assert(
  (select bool_and(invite_short_code ~ '^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{7}$')
   from public.family_spaces where name like 'Seed family %'),
  'seeded short codes must use the safe alphabet');

-- Old insert path: no code supplied, the trigger fills it.
insert into public.family_spaces (name, created_by)
values ('Old app family', 'b1111111-1111-1111-1111-111111111111');
select pg_temp._assert(
  (select invite_short_code from public.family_spaces where name = 'Old app family') ~ '^[2-9A-HJKMNP-Z]{7}$',
  'an insert without a code must still work');

-- Old UUID join keeps working, and is unchanged.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"b2222222-2222-2222-2222-222222222222"}';
select public.join_family_space((select val::uuid from _state where key = 'old_uuid'));
reset role;
select pg_temp._assert(
  exists (select 1 from public.family_memberships
          where user_id = 'b2222222-2222-2222-2222-222222222222'
            and space_id = (select id from public.family_spaces where name = 'Seed family 1')),
  'the old UUID join must still work');
select pg_temp._assert(
  md5(pg_get_functiondef('public.join_family_space(uuid)'::regprocedure))
    = (select val from _state where key = 'join_md5'),
  'join_family_space(uuid) must be unchanged');

-- 4. 0011: existing names untouched, new users get NULL or a trimmed name.
select pg_temp._assert(
  (select display_name from public.profiles where id = 'b2222222-2222-2222-2222-222222222222') = 'old.joiner',
  '0011 must not rewrite existing names');
insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_user_meta_data) values
  ('b3333333-3333-3333-3333-333333333333', 'authenticated', 'authenticated', 'new.noname@test.local', '', now(), now(), now(), '{}'),
  ('b4444444-4444-4444-4444-444444444444', 'authenticated', 'authenticated', 'new.long@test.local', '', now(), now(), now(),
    jsonb_build_object('display_name', '  ' || repeat('x', 60) || '  '));
select pg_temp._assert(
  (select display_name from public.profiles where id = 'b3333333-3333-3333-3333-333333333333') is null,
  'a new user without a name must get NULL, not the email prefix');
select pg_temp._assert(
  (select char_length(display_name) from public.profiles where id = 'b4444444-4444-4444-4444-444444444444') = 40,
  'a chosen name must be trimmed to 40');
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"b3333333-3333-3333-3333-333333333333"}';
select public.set_my_display_name('  Nour  ');
reset role;
select pg_temp._assert(
  (select display_name from public.profiles where id = 'b3333333-3333-3333-3333-333333333333') = 'Nour',
  'set_my_display_name must save the trimmed name');
do $$ begin
  set local role authenticated;
  perform public.set_my_display_name(repeat('y', 41));
  raise exception 'UPGRADE TEST FAILED: a 41 character name was accepted';
exception when others then
  reset role;
  if sqlstate <> '22023' then raise; end if;
end $$;

-- 5. Rollback with data present: families and the old join survive.
select pg_temp._rollback();
select pg_temp._assert(
  (select count(*) from public.family_spaces where name like 'Seed family %') = 200,
  'rollback with data must keep every family');
select pg_temp._assert(
  (select count(*) from public.family_memberships where user_id = 'b2222222-2222-2222-2222-222222222222') = 1,
  'rollback with data must keep memberships');
select pg_temp._assert(
  md5(pg_get_functiondef('public.join_family_space(uuid)'::regprocedure))
    = (select val from _state where key = 'join_md5'),
  'join_family_space(uuid) must still be the original after rollback');
insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_user_meta_data) values
  ('b5555555-5555-5555-5555-555555555555', 'authenticated', 'authenticated', 'after.rollback@test.local', '', now(), now(), now(), '{}');
select pg_temp._assert(
  (select display_name from public.profiles where id = 'b5555555-5555-5555-5555-555555555555') = 'after.rollback',
  'rollback must restore the previous handle_new_user');

-- 6. Collision atomicity: force every generated code to be identical so the
-- unique index step fails, and check the whole of 0010 is undone.
do $$
declare v_failed boolean := false;
begin
  begin
    perform pg_temp._apply('0010',
      $h$create or replace function public.generate_short_code() returns text
         language sql as $f$ select 'AAAAAAA'::text $f$$h$);
  exception when unique_violation then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'UPGRADE TEST FAILED: forced duplicate codes did not fail the migration';
  end if;
end $$;
select pg_temp._assert(
  not exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'family_spaces'
                and column_name = 'invite_short_code')
  and to_regprocedure('public.generate_short_code()') is null
  and to_regprocedure('public.join_family_space_by_code(text)') is null,
  'a failed 0010 must leave no partial column or function');
select pg_temp._assert(
  (select count(*) from public.family_spaces where name like 'Seed family %') = 200,
  'a failed 0010 must leave the data intact');

select extensions.ok(true, 'upgrade 0010 0011');
select * from extensions.finish();
rollback;
