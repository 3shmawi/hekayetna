-- Tests for migration 0007_family_fixes.sql: creating a family through the
-- app's real path, account deletion, owner hand-over, rows that can't move
-- to another family, and the file list for account deletion.
-- Run in CI:  supabase test db
-- Every check raises on failure; the suite runs in one transaction and rolls
-- back.

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
    raise exception 'RLS TEST FAILED: %', p_msg;
  end if;
end $$;
grant execute on function pg_temp._assert(boolean, text) to authenticated, anon;

-- u1 creates a family, u2 joins it, u3 has a family of their own.
insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
  ('f1111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'f1@test.local', '', now(), now(), now()),
  ('f2222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'f2@test.local', '', now(), now(), now()),
  ('f3333333-3333-3333-3333-333333333333', 'authenticated', 'authenticated', 'f3@test.local', '', now(), now(), now());

-- ---------- 1. create a family the way the app does ----------
create temp table _ids (key text primary key, id uuid);
grant all on _ids to authenticated;

set local role authenticated;
set local "request.jwt.claims" = '{"sub":"f1111111-1111-1111-1111-111111111111"}';
insert into _ids values ('space1', public.create_family_space('  The Family  '));
select pg_temp._assert(
  (select role from public.family_memberships
   where space_id = (select id from _ids where key = 'space1')
     and user_id = 'f1111111-1111-1111-1111-111111111111') = 'owner',
  'the creator must be the owner of the new space');
select pg_temp._assert(
  (select name from public.family_spaces where id = (select id from _ids where key = 'space1')) = 'The Family',
  'the creator must read back the new space (trimmed name)');

-- Blank and too-long names are rejected by the table's check.
do $$
begin
  perform public.create_family_space('   ');
  raise exception 'RLS TEST FAILED: blank family name accepted';
exception when check_violation then null;
end $$;
do $$
begin
  perform public.create_family_space(repeat('x', 81));
  raise exception 'RLS TEST FAILED: 81-character family name accepted';
exception when check_violation then null;
end $$;

-- Signed out: no family.
set local role anon;
set local "request.jwt.claims" = '{}';
do $$
begin
  perform public.create_family_space('Nope');
  raise exception 'RLS TEST FAILED: anon created a family';
exception when insufficient_privilege then null;
end $$;

-- u3's own family, u2 joins u1's.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"f3333333-3333-3333-3333-333333333333"}';
insert into _ids values ('space3', public.create_family_space('Other Family'));

set local role postgres;
insert into _ids values ('invite1', (select invite_code from public.family_spaces where id = (select id from _ids where key = 'space1')));
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"f2222222-2222-2222-2222-222222222222"}';
select public.join_family_space((select id from _ids where key = 'invite1'));

-- ---------- 2. rows can't move to another family ----------
set local "request.jwt.claims" = '{"sub":"f1111111-1111-1111-1111-111111111111"}';
insert into public.stories (id, space_id, title, visibility, audio_path, created_by) values
  ('f0000000-0000-0000-0000-000000000001', (select id from _ids where key = 'space1'), 'Story', 'private', 'x',
   'f1111111-1111-1111-1111-111111111111');
do $$
begin
  update public.stories
  set space_id = (select id from _ids where key = 'space3'), visibility = 'family'
  where id = 'f0000000-0000-0000-0000-000000000001';
  raise exception 'RLS TEST FAILED: a story moved to another family';
exception when insufficient_privilege then null;
end $$;
do $$
begin
  update public.family_memberships
  set user_id = 'f3333333-3333-3333-3333-333333333333'
  where user_id = 'f2222222-2222-2222-2222-222222222222';
  raise exception 'RLS TEST FAILED: the owner rewrote a membership to another user';
exception when insufficient_privilege then null;
end $$;

-- Ordinary edits still work.
update public.stories set title = 'Renamed' where id = 'f0000000-0000-0000-0000-000000000001';
select pg_temp._assert(
  (select title from public.stories where id = 'f0000000-0000-0000-0000-000000000001') = 'Renamed',
  'the creator must still edit their story');

-- ---------- 3. account deletion ----------
set local role postgres;
insert into storage.buckets (id, name, public) values ('story-audio', 'story-audio', false) on conflict (id) do nothing;
insert into storage.buckets (id, name, public) values ('family-photos', 'family-photos', false) on conflict (id) do nothing;
insert into storage.objects (bucket_id, name, owner) values
  ('story-audio', (select id from _ids where key = 'space1') || '/f1111111-1111-1111-1111-111111111111/f0000000-0000-0000-0000-000000000001/a.m4a',
   'f1111111-1111-1111-1111-111111111111'),
  ('family-photos', (select id from _ids where key = 'space1') || '/persons/p.jpg',
   'f1111111-1111-1111-1111-111111111111');
insert into public.persons (space_id, full_name, created_by) values
  ((select id from _ids where key = 'space1'), 'Grandma', 'f1111111-1111-1111-1111-111111111111');

-- The file list is for the service role only.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"f2222222-2222-2222-2222-222222222222"}';
do $$
begin
  perform public.storage_objects_of_user('f1111111-1111-1111-1111-111111111111');
  raise exception 'RLS TEST FAILED: a user listed another user''s files';
exception when insufficient_privilege then null;
end $$;

set local role postgres;
select pg_temp._assert(
  (select count(*) from public.storage_objects_of_user('f1111111-1111-1111-1111-111111111111')) = 1,
  'account deletion removes the user''s own uploads, not shared portraits');

delete from auth.users where id = 'f1111111-1111-1111-1111-111111111111';
select pg_temp._assert(
  (select count(*) from public.stories where id = 'f0000000-0000-0000-0000-000000000001') = 0,
  'the deleted user''s stories go with the account');
select pg_temp._assert(
  (select count(*) from public.family_spaces where id = (select id from _ids where key = 'space1')) = 1,
  'the family stays for its other members');
select pg_temp._assert(
  (select count(*) from public.persons where space_id = (select id from _ids where key = 'space1')) = 1,
  'family-tree people stay for the family');

-- ---------- 4. the space keeps an owner ----------
select pg_temp._assert(
  (select role from public.family_memberships
   where space_id = (select id from _ids where key = 'space1')
     and user_id = 'f2222222-2222-2222-2222-222222222222') = 'owner',
  'the remaining member becomes owner when the last owner leaves');

-- Deleting a whole space still works (cascade + owner hand-over trigger).
delete from public.family_spaces where id = (select id from _ids where key = 'space3');
select pg_temp._assert(
  (select count(*) from public.family_memberships where space_id = (select id from _ids where key = 'space3')) = 0,
  'deleting a space removes its memberships');

select extensions.ok(true, 'family fixes suite: all assertion groups passed');
select extensions.finish();
rollback;
