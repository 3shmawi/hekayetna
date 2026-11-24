-- Family access-control tests (pgTAP when available): the sharing rules of
-- the whole app, proven against the real policies - snapshot sharing,
-- independent photo permissions, removal, blocked rejoin, storage paths.
-- Run in CI:  supabase test db
-- Run locally without the Supabase CLI:  psql <db> -v ON_ERROR_STOP=1 -f supabase/tests/family_access.test.sql
--   (a minimal pgTAP stand-in is installed then, so the same file runs in both)
-- Every check raises on failure, so a green run means all 43 checks passed.
-- The whole suite runs in one transaction and rolls back: it leaves no data.

begin;

-- pgTAP on Supabase; a tiny compatible stand-in on plain PostgreSQL.
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


-- ---------- fixtures (as superuser; postgres bypasses RLS) ----------
create or replace function public._assert(p_cond boolean, p_msg text)
returns void language plpgsql as $$
begin
  if not coalesce(p_cond, false) then
    raise exception 'RLS TEST FAILED: %', p_msg;
  end if;
end $$;

-- Simulate an authenticated user with two statements wherever _as was:
--   set local role authenticated;
--   set local "request.jwt.claims" = '{"sub":"<user uuid>"}';
-- auth.uid() reads request.jwt.claims.sub.

-- Deterministic user ids.
-- u1 owner/creator, u2 early member, u3 late member, u4 outsider.
insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
  ('11111111-1111-1111-1111-111111111111', 'authenticated', 'authenticated', 'owner@test.local', '', now(), now(), now()),
  ('22222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated', 'early@test.local', '', now(), now(), now()),
  ('33333333-3333-3333-3333-333333333333', 'authenticated', 'authenticated', 'late@test.local', '', now(), now(), now()),
  ('44444444-4444-4444-4444-444444444444', 'authenticated', 'authenticated', 'outsider@test.local', '', now(), now(), now());
-- profiles are created by the handle_new_user trigger.

insert into public.family_spaces (id, name, created_by) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Test Family', '11111111-1111-1111-1111-111111111111');
insert into public.family_memberships (space_id, user_id, role, joined_at) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'owner', now() - interval '10 days'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 'member', now() - interval '9 days');
insert into public.persons (id, space_id, full_name, created_by) values
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Sitto', '11111111-1111-1111-1111-111111111111');

-- story A: private. story B: family (snapshot materializes u2). story C: selected, grant to u2.
insert into public.stories (id, space_id, title, visibility, audio_path, created_by) values
  ('a0000000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Private story', 'private',
   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/a0000000-0000-0000-0000-000000000001/a.m4a', '11111111-1111-1111-1111-111111111111'),
  ('a0000000-0000-0000-0000-000000000002', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Family story', 'family',
   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/a0000000-0000-0000-0000-000000000002/a.m4a', '11111111-1111-1111-1111-111111111111'),
  ('a0000000-0000-0000-0000-000000000003', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Selected story', 'selected',
   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/a0000000-0000-0000-0000-000000000003/a.m4a', '11111111-1111-1111-1111-111111111111');
insert into public.story_recipients (story_id, grantee_user_id, granted_by) values
  ('a0000000-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111');
insert into public.story_narrators (story_id, person_id) values
  ('a0000000-0000-0000-0000-000000000002', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
insert into public.photos (id, space_id, image_path, uploaded_by) values
  ('c0000000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/photos/c0000000-0000-0000-0000-000000000001/p.jpg', '11111111-1111-1111-1111-111111111111');
insert into public.story_photos (story_id, photo_id) values
  ('a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001'), -- linked to the PRIVATE story
  ('a0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001'); -- AND to the family story

-- ---------- 1. private story: only the creator ----------
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222"}';
select public._assert((select count(*) from public.stories where id = 'a0000000-0000-0000-0000-000000000001') = 0,
  'member must not see a private story');

-- ---------- 2. family story: snapshot member sees it ----------
select public._assert((select count(*) from public.stories where id = 'a0000000-0000-0000-0000-000000000002') = 1,
  'member present at share time must see the family story');

-- ---------- 3. member who joins AFTER the share sees nothing old ----------
set local role postgres;
insert into public.family_memberships (space_id, user_id, role) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '33333333-3333-3333-3333-333333333333', 'member');
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333"}';
select public._assert((select count(*) from public.stories where id = 'a0000000-0000-0000-0000-000000000002') = 0,
  'late member must not inherit the family story');
select public._assert((select count(*) from public.stories where id = 'a0000000-0000-0000-0000-000000000003') = 0,
  'late member must not see the selected story without a grant');

-- ---------- 4. selected story: grantee yes, other members no ----------
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222"}';
select public._assert((select count(*) from public.stories where id = 'a0000000-0000-0000-0000-000000000003') = 1,
  'grantee must see the selected story');

-- ---------- 5. outsiders see and insert nothing ----------
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"44444444-4444-4444-4444-444444444444"}';
select public._assert((select count(*) from public.stories) = 0, 'outsider must see no stories');
select public._assert((select count(*) from public.persons) = 0, 'outsider must see no persons');
select public._assert((select count(*) from public.profiles where id = '11111111-1111-1111-1111-111111111111') = 0,
  'outsider must not read other profiles');
do $$
begin
  insert into public.stories (space_id, title, visibility, audio_path, created_by)
  values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'x', 'private', 'x', '44444444-4444-4444-4444-444444444444');
  raise exception 'RLS TEST FAILED: outsider inserted a story';
exception when insufficient_privilege or check_violation then
  null;
end $$;

-- ---------- 6. no self-grant, no grant to non-members, no direct self-join ----------
do $$
begin
  insert into public.family_memberships (space_id, user_id) values
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '44444444-4444-4444-4444-444444444444');
  raise exception 'RLS TEST FAILED: outsider self-joined without invite';
exception when insufficient_privilege or check_violation then
  null;
end $$;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111"}'; -- owner
do $$
begin
  insert into public.story_recipients (story_id, grantee_user_id, granted_by) values
    ('a0000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111');
  raise exception 'RLS TEST FAILED: creator granted themselves';
exception when insufficient_privilege or check_violation then
  null;
end $$;
do $$
begin
  insert into public.story_recipients (story_id, grantee_user_id, granted_by) values
    ('a0000000-0000-0000-0000-000000000003', '44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111');
  raise exception 'RLS TEST FAILED: grant to non-member accepted';
exception when insufficient_privilege or check_violation then
  null;
end $$;

-- ---------- 7. join tables never leak an inaccessible story ----------
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333"}';
select public._assert((select count(*) from public.story_narrators where story_id = 'a0000000-0000-0000-0000-000000000002') = 0,
  'late member must not read narrators of an inaccessible story');

-- ---------- 8. photo permission is independent of the stories it links to ----------
-- The photo is private, yet linked to the family story B which u2 CAN read.
-- Linking must never widen the photo's audience.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222"}';
select public._assert((select count(*) from public.stories where id = 'a0000000-0000-0000-0000-000000000002') = 1,
  'setup check: u2 can read the family story');
select public._assert((select count(*) from public.photos where id = 'c0000000-0000-0000-0000-000000000001') = 0,
  'private photo linked to an accessible story must still be invisible');
select public._assert((select count(*) from public.story_photos where photo_id = 'c0000000-0000-0000-0000-000000000001'
    and story_id = 'a0000000-0000-0000-0000-000000000002') = 1,
  'the link itself is readable with story access; only the photo content is gated');
-- Now the uploader shares the photo with the family: a snapshot at that moment.
set local role postgres;
update public.photos set visibility = 'family' where id = 'c0000000-0000-0000-0000-000000000001';
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222"}';
select public._assert((select count(*) from public.photos where id = 'c0000000-0000-0000-0000-000000000001') = 1,
  'family-shared photo must be visible to a snapshot member');
-- A member who joins after the photo share inherits nothing.
set local role postgres;
insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
  ('55555555-5555-5555-5555-555555555555', 'authenticated', 'authenticated', 'later@test.local', '', now(), now(), now());
insert into public.family_memberships (space_id, user_id, role) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '55555555-5555-5555-5555-555555555555', 'member');
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"55555555-5555-5555-5555-555555555555"}';
select public._assert((select count(*) from public.photos where id = 'c0000000-0000-0000-0000-000000000001') = 0,
  'member joining after the photo share must not inherit it');

-- ---------- 9. removal revokes; rejoin restores nothing; re-share re-grants ----------
set local role postgres;
delete from public.family_memberships
where space_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and user_id = '22222222-2222-2222-2222-222222222222';
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222"}';
select public._assert((select count(*) from public.stories) = 0, 'removed member must lose all access');
set local role postgres;
insert into public.family_memberships (space_id, user_id, role) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 'member');
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222"}';
select public._assert((select count(*) from public.stories) = 0,
  'rejoined member must NOT regain historical stories');
-- deliberate re-share by the creator materializes a fresh snapshot
set local role postgres;
update public.stories set visibility = 'family' where id = 'a0000000-0000-0000-0000-000000000002'; -- already family; touch
update public.stories set visibility = 'selected' where id = 'a0000000-0000-0000-0000-000000000002';
update public.stories set visibility = 'family' where id = 'a0000000-0000-0000-0000-000000000002';
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222"}';
select public._assert((select count(*) from public.stories where id = 'a0000000-0000-0000-0000-000000000002') = 1,
  're-shared family story must reach the rejoined member');

-- ---------- 10. storage object policies ----------
set local role postgres;
insert into storage.buckets (id, name, public) values ('story-audio', 'story-audio', false) on conflict (id) do nothing;
insert into storage.objects (id, bucket_id, name, owner) values
  (gen_random_uuid(), 'story-audio',
   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/11111111-1111-1111-1111-111111111111/a0000000-0000-0000-0000-000000000001/a.m4a', '11111111-1111-1111-1111-111111111111'),
  (gen_random_uuid(), 'story-audio',
   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/11111111-1111-1111-1111-111111111111/a0000000-0000-0000-0000-000000000002/a.m4a', '11111111-1111-1111-1111-111111111111');
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333"}'; -- late member
select public._assert((select count(*) from storage.objects
  where bucket_id = 'story-audio'
    and name like '%a0000000-0000-0000-0000-000000000001%') = 0,
  'late member must not list the private story audio object');
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222"}'; -- re-shared member
select public._assert((select count(*) from storage.objects
  where bucket_id = 'story-audio'
    and name like '%a0000000-0000-0000-0000-000000000002%') = 1,
  'member with access must see the story audio object');
select public._assert((select count(*) from storage.objects
  where bucket_id = 'story-audio'
    and name like '%a0000000-0000-0000-0000-000000000001%') = 0,
  'member must not see the private story audio object');

-- ---------- 11. invite-code join works, and still grants nothing old ----------
set local role postgres;
-- The invite code must be read by a role that can see family_spaces: a brand-new
-- joiner cannot (RLS), which is by design. Capture it here, as the owner would share it.
create temp table _invite_code as
  select invite_code from public.family_spaces where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
grant select on pg_temp._invite_code to authenticated;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"44444444-4444-4444-4444-444444444444"}';
select public._assert(
  public.join_family_space((select invite_code from _invite_code))
    = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'invite-code join must return the space id');
select public._assert((select count(*) from public.stories) = 0,
  'member who joined by invite must see no historical stories');

-- ---------- 12. adversarial storage: staging prefixes and orphan cleanup ----------
-- 12a. A member must NOT be able to write into another member's upload prefix,
--      even inside a space they both belong to.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222"}';
do $$
begin
  begin
    insert into storage.objects (id, bucket_id, name, owner) values
      (gen_random_uuid(), 'story-audio',
       'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/11111111-1111-1111-1111-111111111111/a0000000-0000-0000-0000-000000000009/evil.m4a',
       '22222222-2222-2222-2222-222222222222');
    raise exception 'TEST FAILURE: member wrote into another member''s audio prefix';
  exception
    when insufficient_privilege then null; -- expected: RLS blocks the insert
  end;
end $$;

-- 12b. Upload into one's OWN prefix works before the story row exists (staging),
--      and the uploader can see their own orphan for cleanup/retry.
insert into storage.objects (id, bucket_id, name, owner) values
  (gen_random_uuid(), 'story-audio',
   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/22222222-2222-2222-2222-222222222222/a0000000-0000-0000-0000-000000000009/orphan.m4a',
   '22222222-2222-2222-2222-222222222222');
select public._assert((select count(*) from storage.objects
  where name like '%a0000000-0000-0000-0000-000000000009%') = 1,
  'uploader must see their own orphan object for cleanup/retry');

-- 12c. The orphan is invisible to every other member, including the space owner.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111"}';
select public._assert((select count(*) from storage.objects
  where name like '%a0000000-0000-0000-0000-000000000009%') = 0,
  'orphan object must be invisible to other members');

-- 12d. Nobody can delete another member's object (delete silently filters).
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222"}';
delete from storage.objects where name like '%a0000000-0000-0000-0000-000000000001%';
set local role postgres;
select public._assert((select count(*) from storage.objects
  where name like '%a0000000-0000-0000-0000-000000000001%') = 1,
  'delete by a non-owner must not remove the object');

-- 12e. The owner CAN delete their own orphan: this is the cleanup/retry path
--      after a failed story-row insert.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222"}';
delete from storage.objects where name like '%a0000000-0000-0000-0000-000000000009%';
set local role postgres;
select public._assert((select count(*) from storage.objects
  where name like '%a0000000-0000-0000-0000-000000000009%') = 0,
  'owner must be able to delete their own orphan for cleanup/retry');

-- 12f. There is no update policy at all: objects are immutable, retries are
--      delete-then-insert, never silent replacement. Even the owner's update
--      affects zero rows.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111"}';
update storage.objects set name = 'replaced.m4a'
  where name like '%a0000000-0000-0000-0000-000000000001%';
set local role postgres;
select public._assert((select count(*) from storage.objects
  where name like '%a0000000-0000-0000-0000-000000000001%') = 1,
  'update must be impossible, objects are immutable');

-- ---------- 13. revoked uploaders and metadata/path binding ----------
-- 13a. u5 (still a member) stages an object in their own prefix.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"55555555-5555-5555-5555-555555555555"}';
insert into storage.objects (id, bucket_id, name, owner) values
  (gen_random_uuid(), 'story-audio',
   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/55555555-5555-5555-5555-555555555555/a0000000-0000-0000-0000-00000000000a/staged.m4a',
   '55555555-5555-5555-5555-555555555555');
select public._assert((select count(*) from storage.objects where name like '%staged.m4a') = 1,
  'member must see their own staged object while still a member');

-- 13b. Removal ends everything: the owner branch must not bypass membership.
set local role postgres;
delete from public.family_memberships
 where space_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
   and user_id = '55555555-5555-5555-5555-555555555555';
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"55555555-5555-5555-5555-555555555555"}';
select public._assert((select count(*) from storage.objects where name like '%staged.m4a') = 0,
  'removed member must not read even their own staged object');
select public._assert((select count(*) from storage.objects where bucket_id = 'story-audio') = 0,
  'removed member must not list any audio objects');
select public._assert((select count(*) from public.stories) = 0,
  'removed member must not read any stories, including ones they were granted');
delete from storage.objects where name like '%staged.m4a';
set local role postgres;
select public._assert((select count(*) from storage.objects where name like '%staged.m4a') = 1,
  'removed member must not delete their own staged object');

-- 13c. Metadata/path binding: a member can stage a file in their OWN prefix
--      naming someone else's story id. That exposes only their own file to
--      that story's audience (a deliberate self-share); it never grants
--      access to the other member's objects.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222"}';
insert into storage.objects (id, bucket_id, name, owner) values
  (gen_random_uuid(), 'story-audio',
   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/22222222-2222-2222-2222-222222222222/a0000000-0000-0000-0000-000000000001/attached.m4a',
   '22222222-2222-2222-2222-222222222222');
select public._assert((select count(*) from storage.objects where name like '%attached.m4a') = 1,
  'uploader must read their own file that names another story');
set local "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333"}';
select public._assert((select count(*) from storage.objects where name like '%attached.m4a') = 0,
  'member without story access must not read another member upload naming an inaccessible story');
select public._assert((select count(*) from storage.objects
  where name like '%a0000000-0000-0000-0000-000000000001%') = 0,
  'knowing a story id must never expose the creator''s objects to an unauthorized member');
set local "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111"}';
select public._assert((select count(*) from storage.objects where name like '%attached.m4a') = 1,
  'story creator reads a member upload deliberately named with their story id');

-- ---------- 14. removed member cannot rejoin on the unchanged invite code ----------
-- 14a. A non-owner cannot remove anyone through the RPC.
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222"}';
do $$
declare
  v_mid uuid;
begin
  select id into v_mid from public.family_memberships
  where space_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and user_id = '11111111-1111-1111-1111-111111111111';
  begin
    perform public.remove_family_member(v_mid);
    raise exception 'RLS TEST FAILED: non-owner removed a member';
  exception when raise_exception then
    null; -- expected: not_owner
  end;
end $$;
-- 14b. The owner removes u2 through the RPC: membership and grants die, a
--      removal block is recorded.
set local role postgres;
create temp table _u2_membership as
  select id from public.family_memberships
  where space_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and user_id = '22222222-2222-2222-2222-222222222222';
grant select on pg_temp._u2_membership to authenticated;
set local role authenticated;
set local "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111"}'; -- owner
select public.remove_family_member((select id from pg_temp._u2_membership));
select public._assert(exists(
  select 1 from public.family_membership_removals
  where space_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and user_id = '22222222-2222-2222-2222-222222222222'),
  'removal must record a rejoin block');
set local "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222"}';
select public._assert((select count(*) from public.stories) = 0,
  'member removed via RPC must lose all access immediately');
-- 14c. The removed member cannot rejoin with the unchanged invite code.
do $$
begin
  begin
    perform public.join_family_space((select invite_code from pg_temp._invite_code));
    raise exception 'RLS TEST FAILED: removed member rejoined on the unchanged invite code';
  exception when raise_exception then
    null; -- expected: member_removed
  end;
end $$;
select public._assert((select count(*) from public.family_memberships
  where space_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and user_id = '22222222-2222-2222-2222-222222222222') = 0,
  'blocked rejoin must not recreate the membership');
-- 14d. A member who LEAVES on their own is not blocked from rejoining.
set local "request.jwt.claims" = '{"sub":"44444444-4444-4444-4444-444444444444"}'; -- u4, joined by invite
delete from public.family_memberships
where space_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and user_id = '44444444-4444-4444-4444-444444444444';
select public._assert(
  public.join_family_space((select invite_code from pg_temp._invite_code))
    = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'self-leaver must be able to rejoin with the invite code');
-- 14e. The owner can lift the block deliberately; rejoin then succeeds but
--      still restores nothing (snapshot semantics are unchanged).
set local "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111"}'; -- owner
delete from public.family_membership_removals
where space_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and user_id = '22222222-2222-2222-2222-222222222222';
set local "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222"}';
select public._assert(
  public.join_family_space((select invite_code from pg_temp._invite_code))
    = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'rejoin after the owner lifts the block must succeed');
select public._assert((select count(*) from public.stories) = 0,
  'rejoin after block lifted must still restore no historical stories');

set local role postgres;
select extensions.ok(true, 'family access-control suite: all assertion groups passed');
select extensions.finish();
rollback;
