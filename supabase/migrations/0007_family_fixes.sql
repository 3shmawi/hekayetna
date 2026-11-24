-- Family Stories - fixes found in review (2026-11-24).
-- Migration 7:
--  1. create_family_space(name): creating a family was impossible under RLS.
--     The creator is not a member yet, so `insert ... returning` on
--     family_spaces failed the select policy, and memberships_insert forbids
--     adding yourself. The RPC creates the space and its owner membership in
--     one transaction.
--  2. Account deletion: every `created_by` / `uploaded_by` / `granted_by`
--     foreign key had no ON DELETE action, so deleting a user who had created
--     a family, a story or a photo failed (Apple and Google require in-app
--     account deletion). Personal content now goes with the account; shared
--     directory data (spaces, persons, relationships) stays with the family
--     and forgets who created it.
--  3. A space never loses its last owner: when the last owner leaves or
--     deletes their account, the longest-standing member becomes owner.
--  4. Rows can't be moved to another family: space_id (and a membership's
--     user_id) is fixed after insert. Before this, a story's creator could
--     move it into any space by id and the family-share trigger pushed it to
--     that family's members.
--  5. storage_objects_of_user(user): the files the delete-account Edge
--     Function removes before deleting the user (service role only).

-- ---------- 1. create a family space ----------
create or replace function public.create_family_space(p_name text)
returns uuid
language plpgsql security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_space_id uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  insert into public.family_spaces (name, created_by)
  values (trim(p_name), v_uid)
  returning id into v_space_id;
  insert into public.family_memberships (space_id, user_id, role)
  values (v_space_id, v_uid, 'owner');
  return v_space_id;
end;
$$;

revoke execute on function public.create_family_space(text) from public, anon;
grant execute on function public.create_family_space(text) to authenticated;

-- ---------- 2. account deletion ----------
alter table public.family_spaces alter column created_by drop not null;
alter table public.family_spaces drop constraint family_spaces_created_by_fkey;
alter table public.family_spaces add constraint family_spaces_created_by_fkey
  foreign key (created_by) references public.profiles (id) on delete set null;

alter table public.persons alter column created_by drop not null;
alter table public.persons drop constraint persons_created_by_fkey;
alter table public.persons add constraint persons_created_by_fkey
  foreign key (created_by) references public.profiles (id) on delete set null;

alter table public.relationships alter column created_by drop not null;
alter table public.relationships drop constraint relationships_created_by_fkey;
alter table public.relationships add constraint relationships_created_by_fkey
  foreign key (created_by) references public.profiles (id) on delete set null;

alter table public.stories drop constraint stories_created_by_fkey;
alter table public.stories add constraint stories_created_by_fkey
  foreign key (created_by) references public.profiles (id) on delete cascade;

alter table public.photos drop constraint photos_uploaded_by_fkey;
alter table public.photos add constraint photos_uploaded_by_fkey
  foreign key (uploaded_by) references public.profiles (id) on delete cascade;

alter table public.story_recipients drop constraint story_recipients_granted_by_fkey;
alter table public.story_recipients add constraint story_recipients_granted_by_fkey
  foreign key (granted_by) references public.profiles (id) on delete cascade;

alter table public.photo_recipients drop constraint photo_recipients_granted_by_fkey;
alter table public.photo_recipients add constraint photo_recipients_granted_by_fkey
  foreign key (granted_by) references public.profiles (id) on delete cascade;

-- Keep the rejoin block when the owner who removed someone deletes their
-- account.
alter table public.family_membership_removals alter column removed_by drop not null;
alter table public.family_membership_removals drop constraint family_membership_removals_removed_by_fkey;
alter table public.family_membership_removals add constraint family_membership_removals_removed_by_fkey
  foreign key (removed_by) references auth.users (id) on delete set null;

-- ---------- 3. never leave a space without an owner ----------
create or replace function public.promote_owner_after_leave()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  if old.role = 'owner' and not exists (
    select 1 from public.family_memberships
    where space_id = old.space_id and role = 'owner'
  ) then
    update public.family_memberships set role = 'owner'
    where id = (
      select id from public.family_memberships
      where space_id = old.space_id
      order by joined_at, id
      limit 1
    );
  end if;
  return old;
end;
$$;

drop trigger if exists memberships_promote_owner on public.family_memberships;
create trigger memberships_promote_owner
  after delete on public.family_memberships
  for each row execute function public.promote_owner_after_leave();

-- ---------- 4. rows stay in their family ----------
create or replace function public.keep_space_id()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.space_id is distinct from old.space_id then
    raise exception 'space_id_is_immutable' using errcode = '42501';
  end if;
  return new;
end;
$$;

create or replace function public.keep_membership_identity()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.space_id is distinct from old.space_id
     or new.user_id is distinct from old.user_id then
    raise exception 'membership_identity_is_immutable' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists stories_keep_space on public.stories;
create trigger stories_keep_space before update on public.stories
  for each row execute function public.keep_space_id();
drop trigger if exists photos_keep_space on public.photos;
create trigger photos_keep_space before update on public.photos
  for each row execute function public.keep_space_id();
drop trigger if exists persons_keep_space on public.persons;
create trigger persons_keep_space before update on public.persons
  for each row execute function public.keep_space_id();
drop trigger if exists relationships_keep_space on public.relationships;
create trigger relationships_keep_space before update on public.relationships
  for each row execute function public.keep_space_id();
drop trigger if exists memberships_keep_identity on public.family_memberships;
create trigger memberships_keep_identity before update on public.family_memberships
  for each row execute function public.keep_membership_identity();

-- ---------- 5. files to remove on account deletion ----------
-- The user's own uploads (story audio, photos). Shared person portraits
-- (`<space>/persons/...`) stay with the family.
create or replace function public.storage_objects_of_user(p_user_id uuid)
returns table (bucket_id text, name text)
language sql stable security definer
set search_path = public
as $$
  select o.bucket_id, o.name
  from storage.objects o
  where o.bucket_id in ('story-audio', 'family-photos')
    and o.owner = p_user_id
    and public.storage_segment_text(o.name, 2) = p_user_id::text;
$$;

revoke execute on function public.storage_objects_of_user(uuid) from public, anon, authenticated;
grant execute on function public.storage_objects_of_user(uuid) to service_role;
