-- Tests for migration 0008_story_waveform.sql: the waveform column accepts
-- 0-100 values (at most 128), rejects anything else, and only the story's
-- creator can change it.
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
    raise exception 'WAVEFORM TEST FAILED: %', p_msg;
  end if;
end $$;
grant execute on function pg_temp._assert(boolean, text) to authenticated, anon;

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
  ('a1111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'w1@test.local', '', now(), now(), now()),
  ('a2222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'w2@test.local', '', now(), now(), now());

create temp table _ids (key text primary key, id uuid);
grant all on _ids to authenticated;

set local role authenticated;
set local "request.jwt.claims" = '{"sub":"a1111111-1111-1111-1111-111111111111"}';
insert into _ids values ('space', public.create_family_space('Waveform Family'));

set local role postgres;
insert into _ids values ('invite', (select invite_code from public.family_spaces where id = (select id from _ids where key = 'space')));
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"a2222222-2222-2222-2222-222222222222"}';
select public.join_family_space((select id from _ids where key = 'invite'));

-- The creator stores a waveform on create.
set local "request.jwt.claims" = '{"sub":"a1111111-1111-1111-1111-111111111111"}';
insert into public.stories (id, space_id, title, visibility, audio_path, created_by, waveform) values
  ('a0000000-0000-0000-0000-0000000000a1', (select id from _ids where key = 'space'), 'Story', 'family', 'x',
   'a1111111-1111-1111-1111-111111111111', (select array_agg((i % 101)::smallint) from generate_series(1, 64) i));
select pg_temp._assert(
  (select array_length(waveform, 1) from public.stories where id = 'a0000000-0000-0000-0000-0000000000a1') = 64,
  'the creator reads back 64 waveform values');

-- Out-of-range or too-long waveforms are rejected.
do $$
begin
  update public.stories set waveform = array[101]::smallint[] where id = 'a0000000-0000-0000-0000-0000000000a1';
  raise exception 'WAVEFORM TEST FAILED: value above 100 accepted';
exception when check_violation then null;
end $$;
do $$
begin
  update public.stories set waveform = array[-1]::smallint[] where id = 'a0000000-0000-0000-0000-0000000000a1';
  raise exception 'WAVEFORM TEST FAILED: negative value accepted';
exception when check_violation then null;
end $$;
do $$
begin
  update public.stories
  set waveform = (select array_agg(1::smallint) from generate_series(1, 129))
  where id = 'a0000000-0000-0000-0000-0000000000a1';
  raise exception 'WAVEFORM TEST FAILED: 129 values accepted';
exception when check_violation then null;
end $$;

-- Another member can read the story but cannot change its waveform.
set local "request.jwt.claims" = '{"sub":"a2222222-2222-2222-2222-222222222222"}';
update public.stories set waveform = array[5]::smallint[] where id = 'a0000000-0000-0000-0000-0000000000a1';
select pg_temp._assert(
  (select array_length(waveform, 1) from public.stories where id = 'a0000000-0000-0000-0000-0000000000a1') = 64,
  'a member must not change another member''s waveform');

select extensions.ok(true, 'story waveform suite: all assertion groups passed');
select extensions.finish();
rollback;
