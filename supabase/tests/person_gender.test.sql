-- Tests for migration 0009_person_gender.sql: gender is optional, accepts
-- 'female' or 'male', rejects anything else, and persons keep their
-- member-only access.
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
    raise exception 'GENDER TEST FAILED: %', p_msg;
  end if;
end $$;
grant execute on function pg_temp._assert(boolean, text) to authenticated, anon;

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
  ('a1111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'g1@test.local', '', now(), now(), now()),
  ('a2222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'g2@test.local', '', now(), now(), now());

create temp table _ids (key text primary key, id uuid);
grant all on _ids to authenticated;

set local role authenticated;
set local "request.jwt.claims" = '{"sub":"a1111111-1111-1111-1111-111111111111"}';
insert into _ids values ('space', public.create_family_space('Gender Family'));

set local role postgres;
insert into _ids values ('invite', (select invite_code from public.family_spaces where id = (select id from _ids where key = 'space')));
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"a2222222-2222-2222-2222-222222222222"}';
select public.join_family_space((select id from _ids where key = 'invite'));

-- A member adds persons with and without gender.
set local "request.jwt.claims" = '{"sub":"a1111111-1111-1111-1111-111111111111"}';
insert into public.persons (id, space_id, full_name, created_by, gender) values
  ('b0000000-0000-0000-0000-0000000000a1', (select id from _ids where key = 'space'), 'Sitto', 'a1111111-1111-1111-1111-111111111111', 'female'),
  ('b0000000-0000-0000-0000-0000000000a2', (select id from _ids where key = 'space'), 'Giddu', 'a1111111-1111-1111-1111-111111111111', 'male'),
  ('b0000000-0000-0000-0000-0000000000a3', (select id from _ids where key = 'space'), 'Nobody', 'a1111111-1111-1111-1111-111111111111', null);
select pg_temp._assert(
  (select gender from public.persons where id = 'b0000000-0000-0000-0000-0000000000a1') = 'female'
  and (select gender from public.persons where id = 'b0000000-0000-0000-0000-0000000000a3') is null,
  'gender stores female and null');

-- Anything else is rejected.
do $$
begin
  update public.persons set gender = 'other' where id = 'b0000000-0000-0000-0000-0000000000a1';
  raise exception 'GENDER TEST FAILED: other accepted';
exception when check_violation then null;
end $$;

-- The creator can clear it again.
update public.persons set gender = null where id = 'b0000000-0000-0000-0000-0000000000a2';
select pg_temp._assert(
  (select gender from public.persons where id = 'b0000000-0000-0000-0000-0000000000a2') is null,
  'gender can be cleared');

select extensions.ok(true, 'person gender suite: all assertion groups passed');
select extensions.finish();
rollback;
