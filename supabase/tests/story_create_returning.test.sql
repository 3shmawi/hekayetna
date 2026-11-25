-- Create-with-RETURNING: the app inserts a story and reads the row back in the
-- same statement (PostgREST insert + select). The creator must be allowed.
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
    raise exception 'CREATE RETURNING TEST FAILED: %', p_msg;
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

set local "request.jwt.claims" = '{"sub":"a1111111-1111-1111-1111-111111111111"}';
create temp table _r (ok boolean, code text);
grant all on _r to authenticated;
do $$
declare v uuid;
begin
  insert into public.stories (id, space_id, title, visibility, audio_path, created_by)
  values ('a0000000-0000-0000-0000-0000000000b1', (select id from _ids where key = 'space'), 'T', 'private', 'x',
          'a1111111-1111-1111-1111-111111111111')
  returning id into v;
  insert into _r values (v is not null, null);
exception when others then
  insert into _r values (false, sqlstate);
end $$;
select pg_temp._assert((select ok from _r), 'insert ... returning failed for the creator, sqlstate ' || coalesce((select code from _r), '?'));
select pg_temp._assert((select count(*) from public.stories where id = 'a0000000-0000-0000-0000-0000000000b1') = 1, 'row readable after insert');

select extensions.ok(true, 'create-with-returning suite passed');
select extensions.finish();
rollback;
