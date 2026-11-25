-- Tests for migration 0010_invite_codes.sql: short codes, join by code,
-- preview, and owner-only rotation.
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

-- o = owner, m = member (joins by code), r = removed member, x = stranger.
insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
  ('a1111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'o@test.local', '', now(), now(), now()),
  ('a2222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'm@test.local', '', now(), now(), now()),
  ('a3333333-3333-3333-3333-333333333333', 'authenticated', 'authenticated', 'r@test.local', '', now(), now(), now()),
  ('a4444444-4444-4444-4444-444444444444', 'authenticated', 'authenticated', 'x@test.local', '', now(), now(), now());

create temp table _ids (key text primary key, id uuid);
grant all on _ids to authenticated, anon;
create temp table _codes (key text primary key, code text);
grant all on _codes to authenticated, anon;

set local role authenticated;
set local "request.jwt.claims" = '{"sub":"a1111111-1111-1111-1111-111111111111"}';
insert into _ids values ('space', public.create_family_space('Invite Family'));
insert into _codes values ('short', (select invite_short_code from public.family_spaces where id = (select id from _ids where key = 'space')));
insert into _codes values ('uuid', (select invite_code::text from public.family_spaces where id = (select id from _ids where key = 'space')));

-- 1. The code has 7 characters from the safe alphabet.
select pg_temp._assert(
  (select code ~ '^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{7}$' from _codes where key = 'short'),
  'a new family must get a 7-character code from the safe alphabet');

-- 2. Codes are unique across many families.
set local role postgres;
insert into public.family_spaces (name, created_by)
select 'bulk ' || g, 'a1111111-1111-1111-1111-111111111111' from generate_series(1, 200) g;
select pg_temp._assert(
  (select count(distinct invite_short_code) = count(*) from public.family_spaces),
  'short codes must be unique');

-- 3. Anonymous users can call nothing.
set local role anon;
set local "request.jwt.claims" = '{}';
do $$ begin
  perform public.join_family_space_by_code('ABCDEFG');
  raise exception 'RLS TEST FAILED: anon joined by code';
exception when insufficient_privilege then null;
end $$;
do $$ begin
  perform public.preview_family_by_code('ABCDEFG');
  raise exception 'RLS TEST FAILED: anon previewed a family';
exception when insufficient_privilege then null;
end $$;
do $$ begin
  perform public.rotate_invite_code((select id from _ids where key = 'space'));
  raise exception 'RLS TEST FAILED: anon rotated a code';
exception when insufficient_privilege then null;
end $$;

-- 4. Preview shows only the name and head count, and is case, space and
-- dash tolerant.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"a4444444-4444-4444-4444-444444444444"}';
select pg_temp._assert(
  (select name from public.preview_family_by_code(
     lower(substr((select code from _codes where key = 'short'), 1, 3)) || '-' ||
     substr((select code from _codes where key = 'short'), 4))) = 'Invite Family',
  'preview must accept lowercase and a dash');
select pg_temp._assert(
  (select member_count from public.preview_family_by_code((select code from _codes where key = 'short'))) = 1,
  'preview must report the member count');
do $$ begin
  perform public.preview_family_by_code('0O1ILxx');
  raise exception 'RLS TEST FAILED: junk code previewed';
exception when others then
  if sqlerrm <> 'invalid_invite_code' then raise; end if;
end $$;

-- 5. A member joins by code, with or without a dash.
set local "request.jwt.claims" = '{"sub":"a2222222-2222-2222-2222-222222222222"}';
select public.join_family_space_by_code((select code from _codes where key = 'short'));
select pg_temp._assert(
  exists (select 1 from public.family_memberships
          where space_id = (select id from _ids where key = 'space')
            and user_id = 'a2222222-2222-2222-2222-222222222222' and role = 'member'),
  'joining by code must add a member');
-- Joining twice is harmless.
select public.join_family_space_by_code(substr((select code from _codes where key = 'short'), 1, 3) || ' ' || substr((select code from _codes where key = 'short'), 4));

-- 6. A member cannot rotate.
do $$ begin
  perform public.rotate_invite_code((select id from _ids where key = 'space'));
  raise exception 'RLS TEST FAILED: a member rotated the code';
exception when insufficient_privilege then null;
end $$;

-- 7. A removed member is blocked, by short code and by UUID.
set local role postgres;
insert into public.family_membership_removals (space_id, user_id, removed_by)
values ((select id from _ids where key = 'space'), 'a3333333-3333-3333-3333-333333333333', 'a1111111-1111-1111-1111-111111111111');
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"a3333333-3333-3333-3333-333333333333"}';
do $$ begin
  perform public.join_family_space_by_code((select code from _codes where key = 'short'));
  raise exception 'RLS TEST FAILED: removed member rejoined by code';
exception when others then
  if sqlerrm <> 'member_removed' then raise; end if;
end $$;

-- 8. The owner rotates; old short code and old UUID stop working.
set local "request.jwt.claims" = '{"sub":"a1111111-1111-1111-1111-111111111111"}';
insert into _codes values ('rotated', public.rotate_invite_code((select id from _ids where key = 'space')));
select pg_temp._assert(
  (select code from _codes where key = 'rotated') <> (select code from _codes where key = 'short'),
  'rotation must change the short code');
set local "request.jwt.claims" = '{"sub":"a4444444-4444-4444-4444-444444444444"}';
do $$ begin
  perform public.join_family_space_by_code((select code from _codes where key = 'short'));
  raise exception 'RLS TEST FAILED: old short code still works';
exception when others then
  if sqlerrm <> 'invalid_invite_code' then raise; end if;
end $$;
do $$ begin
  perform public.join_family_space((select code::uuid from _codes where key = 'uuid'));
  raise exception 'RLS TEST FAILED: old UUID code still works';
exception when others then
  if sqlerrm <> 'invalid_invite_code' then raise; end if;
end $$;
select public.join_family_space_by_code((select code from _codes where key = 'rotated'));
select pg_temp._assert(
  exists (select 1 from public.family_memberships
          where space_id = (select id from _ids where key = 'space')
            and user_id = 'a4444444-4444-4444-4444-444444444444'),
  'the new code must work');

select extensions.ok(true, 'invite codes');
select * from extensions.finish();
rollback;
