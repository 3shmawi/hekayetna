-- Tests for migration 0011_profile_names.sql: no email-prefix names, and
-- set_my_display_name.
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

-- A signup with no chosen name gets no name (not the email prefix).
insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
  ('b1111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'secretprefix@test.local', '', now(), now(), now());
select pg_temp._assert(
  (select display_name is null from public.profiles where id = 'b1111111-1111-1111-1111-111111111111'),
  'a profile must not take its name from the email address');

-- A chosen name from signup metadata is kept, trimmed, and cut at 40.
insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_user_meta_data) values
  ('b2222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'n@test.local', '', now(), now(), now(),
   jsonb_build_object('display_name', '  ' || repeat('x', 60) || '  '));
select pg_temp._assert(
  (select char_length(display_name) = 40 from public.profiles where id = 'b2222222-2222-2222-2222-222222222222'),
  'a signup name must be cut to 40 characters');

-- set_my_display_name saves a trimmed name for the caller only.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"b1111111-1111-1111-1111-111111111111"}';
select pg_temp._assert(public.set_my_display_name('  Sami ') = 'Sami', 'the saved name must be trimmed');
select pg_temp._assert(
  (select display_name from public.profiles where id = 'b1111111-1111-1111-1111-111111111111') = 'Sami',
  'the name must be saved on the caller profile');
select pg_temp._assert(
  (select display_name is distinct from 'Sami' from public.profiles where id = 'b2222222-2222-2222-2222-222222222222'),
  'another profile must not change');

do $$
begin
  perform public.set_my_display_name('   ');
  raise exception 'RLS TEST FAILED: a blank name was saved';
exception when sqlstate '22023' then null;
end $$;
do $$
begin
  perform public.set_my_display_name(repeat('y', 41));
  raise exception 'RLS TEST FAILED: a 41-character name was saved';
exception when sqlstate '22023' then null;
end $$;

-- Anonymous users cannot call it.
set local role anon;
set local "request.jwt.claims" = '{}';
do $$
begin
  perform public.set_my_display_name('Nope');
  raise exception 'RLS TEST FAILED: anon set a name';
exception when insufficient_privilege then null;
end $$;

select extensions.ok(true, 'profile names');
select * from extensions.finish();
rollback;
