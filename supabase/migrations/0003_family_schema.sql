-- Family Stories & Memory Map - family domain schema
-- Migration 3: tables, constraints, indexes, helper functions.
-- Design rules honored here:
--  * UUID keys everywhere; phone numbers and national IDs are never identifiers.
--  * Account (auth.users/profiles), Person (persons), and Story (stories) are separate.
--  * A person exists without an account; linked_user_id is optional and late-bound.
--  * Story visibility defaults to 'private'. Sharing with the family group
--    materializes an explicit snapshot of the members at that moment into
--    story_recipients, so members who join later get NO historical access,
--    and a removed member who rejoins is treated as new (their grants were
--    deleted with their membership).

-- ---------- profiles (table owned by 0002_profiles.sql; extend it here) ----------
alter table public.profiles
  add column if not exists avatar_path text,
  add column if not exists locale text not null default 'en'
    check (locale in ('en', 'ar'));

-- ---------- family_spaces ----------
create table public.family_spaces (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(name) between 1 and 80),
  invite_code uuid not null default gen_random_uuid(), -- rotated on demand; never a person identifier
  created_by  uuid not null references public.profiles (id),
  created_at  timestamptz not null default now()
);

-- ---------- persons (real individuals, account-independent) ----------
create table public.persons (
  id           uuid primary key default gen_random_uuid(),
  space_id     uuid not null references public.family_spaces (id) on delete cascade,
  full_name    text not null check (char_length(full_name) between 1 and 120),
  photo_path   text,
  approx_birth_date text, -- free text: "about 1948", "late 1950s" - precision is often unknown
  approx_death_date text,
  bio          text,
  linked_user_id uuid references public.profiles (id) on delete set null,
  created_by   uuid not null references public.profiles (id),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index persons_space_idx on public.persons (space_id);

-- ---------- family_memberships ----------
create table public.family_memberships (
  id        uuid primary key default gen_random_uuid(),
  space_id  uuid not null references public.family_spaces (id) on delete cascade,
  user_id   uuid not null references public.profiles (id) on delete cascade,
  person_id uuid references public.persons (id) on delete set null, -- which person this member is
  role      text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  unique (space_id, user_id)
);
create index family_memberships_user_idx on public.family_memberships (user_id);
create index family_memberships_space_idx on public.family_memberships (space_id);

-- ---------- relationships ----------
create table public.relationships (
  id                uuid primary key default gen_random_uuid(),
  space_id          uuid not null references public.family_spaces (id) on delete cascade,
  person_id         uuid not null references public.persons (id) on delete cascade,
  related_person_id uuid not null references public.persons (id) on delete cascade,
  type              text not null check (type in ('parent', 'child', 'spouse', 'sibling')),
  status            text not null default 'pending' check (status in ('pending', 'confirmed')),
  created_by        uuid not null references public.profiles (id),
  created_at        timestamptz not null default now(),
  check (person_id <> related_person_id),
  unique (person_id, related_person_id, type)
);
create index relationships_person_idx on public.relationships (person_id);
create index relationships_related_idx on public.relationships (related_person_id);

-- ---------- stories ----------
create table public.stories (
  id               uuid primary key default gen_random_uuid(),
  space_id         uuid not null references public.family_spaces (id) on delete cascade,
  title            text not null check (char_length(title) between 1 and 140),
  description      text,
  topic            text, -- stable topic key, e.g. 'childhood_first_home'; null = free story
  approx_date_label text, -- "summer 1975", "early 80s"
  approx_year      int check (approx_year between 1800 and 2100),
  visibility       text not null default 'private' check (visibility in ('private', 'selected', 'family')),
  audio_path       text not null, -- storage object path in bucket story-audio
  duration_seconds int not null default 0 check (duration_seconds >= 0),
  created_by       uuid not null references public.profiles (id),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index stories_space_recent_idx on public.stories (space_id, created_at desc);
create index stories_topic_idx on public.stories (space_id, topic);
create index stories_year_idx on public.stories (space_id, approx_year);

create table public.story_narrators (
  story_id  uuid not null references public.stories (id) on delete cascade,
  person_id uuid not null references public.persons (id) on delete cascade,
  position  smallint not null default 0, -- narrators stay individually identifiable, in order
  primary key (story_id, person_id)
);
create index story_narrators_person_idx on public.story_narrators (person_id);

create table public.story_people (
  story_id  uuid not null references public.stories (id) on delete cascade,
  person_id uuid not null references public.persons (id) on delete cascade,
  primary key (story_id, person_id)
);
create index story_people_person_idx on public.story_people (person_id);

-- ---------- photos ----------
-- Photos have their own permission, independent of any story they are linked
-- to. Linking a photo to a story never widens the photo's audience: viewing
-- the image requires photo access AND the story link requires story access.
create table public.photos (
  id           uuid primary key default gen_random_uuid(),
  space_id     uuid not null references public.family_spaces (id) on delete cascade,
  image_path   text not null, -- storage object path in bucket family-photos
  caption      text,
  approx_date_label text,
  approx_year  int check (approx_year between 1800 and 2100),
  visibility   text not null default 'private' check (visibility in ('private', 'family')),
  uploaded_by  uuid not null references public.profiles (id),
  created_at   timestamptz not null default now()
);
create index photos_space_idx on public.photos (space_id);

-- Photo access grants, mirroring story_recipients: family sharing
-- materializes a snapshot of the members at that moment.
create table public.photo_recipients (
  photo_id        uuid not null references public.photos (id) on delete cascade,
  grantee_user_id uuid not null references public.profiles (id) on delete cascade,
  granted_by      uuid not null references public.profiles (id),
  created_at      timestamptz not null default now(),
  primary key (photo_id, grantee_user_id)
);
create index photo_recipients_grantee_idx on public.photo_recipients (grantee_user_id);

create table public.photo_people (
  photo_id  uuid not null references public.photos (id) on delete cascade,
  person_id uuid not null references public.persons (id) on delete cascade,
  primary key (photo_id, person_id)
);
create index photo_people_person_idx on public.photo_people (person_id);

create table public.story_photos (
  story_id uuid not null references public.stories (id) on delete cascade,
  photo_id uuid not null references public.photos (id) on delete cascade,
  primary key (story_id, photo_id)
);

-- ---------- story_recipients (grants for visibility = 'selected') ----------
create table public.story_recipients (
  story_id        uuid not null references public.stories (id) on delete cascade,
  grantee_user_id uuid not null references public.profiles (id) on delete cascade,
  granted_by      uuid not null references public.profiles (id),
  created_at      timestamptz not null default now(),
  primary key (story_id, grantee_user_id)
);
create index story_recipients_grantee_idx on public.story_recipients (grantee_user_id);

-- ---------- helper functions ----------
-- security definer so RLS policies can consult membership without recursive
-- policy evaluation; search_path pinned; no row returned, only booleans.

create or replace function public.is_space_member(p_space_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.family_memberships m
    where m.space_id = p_space_id and m.user_id = auth.uid()
  );
$$;

create or replace function public.is_space_owner(p_space_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.family_memberships m
    where m.space_id = p_space_id and m.user_id = auth.uid() and m.role = 'owner'
  );
$$;

-- Central story access rule. Uniform for every visibility level: the
-- creator, or a current space member holding a grant row. Grant rows only
-- ever exist for people who were members when the grant was made:
-- 'selected' grants are inserted one by one by the creator, and 'family'
-- grants are materialized as a snapshot of the member list at share time
-- by the trigger below. The membership-delete trigger removes a departing
-- member's grant rows, so removal revokes and rejoining restores nothing.
create or replace function public.can_access_story(p_story_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.stories s
    where s.id = p_story_id
      and public.is_space_member(s.space_id)
      and (
        s.created_by = auth.uid()
        or (s.visibility in ('selected', 'family') and exists (
              select 1 from public.story_recipients r
              where r.story_id = s.id and r.grantee_user_id = auth.uid()))
      )
  );
$$;

-- Materialize the family-group snapshot: whenever a story becomes visible
-- to the family, grant every current member (except the creator, who needs
-- no grant) a row in story_recipients. Runs as definer so it can see the
-- full member list regardless of the caller's policies.
create or replace function public.materialize_family_share()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  if new.visibility = 'family' then
    insert into public.story_recipients (story_id, grantee_user_id, granted_by)
    select new.id, m.user_id, new.created_by
    from public.family_memberships m
    where m.space_id = new.space_id and m.user_id <> new.created_by
    on conflict (story_id, grantee_user_id) do nothing;
  end if;
  return new;
end;
$$;

create trigger stories_family_share_snapshot
  after insert or update of visibility on public.stories
  for each row execute function public.materialize_family_share();

-- Leaving or being removed from a space revokes that member's grants on
-- every story in the space. Rejoining creates a fresh membership with no
-- grants, which is exactly the "no historical access for new members" rule.
create or replace function public.revoke_grants_on_membership_delete()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  delete from public.story_recipients r
  using public.stories s
  where r.story_id = s.id
    and s.space_id = old.space_id
    and r.grantee_user_id = old.user_id;
  delete from public.photo_recipients r
  using public.photos p
  where r.photo_id = p.id
    and p.space_id = old.space_id
    and r.grantee_user_id = old.user_id;
  return old;
end;
$$;

create trigger memberships_delete_revoke_grants
  after delete on public.family_memberships
  for each row execute function public.revoke_grants_on_membership_delete();

-- Photo rule, independent of stories: the uploader, or a current space
-- member holding a grant row (explicit family-share snapshot). A photo's
-- audience never changes because it was attached to a story.
create or replace function public.can_access_photo(p_photo_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.photos p
    where p.id = p_photo_id
      and public.is_space_member(p.space_id)
      and (
        p.uploaded_by = auth.uid()
        or (p.visibility = 'family' and exists (
              select 1 from public.photo_recipients r
              where r.photo_id = p.id and r.grantee_user_id = auth.uid()))
      )
  );
$$;

create or replace function public.materialize_family_photo_share()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  if new.visibility = 'family' then
    insert into public.photo_recipients (photo_id, grantee_user_id, granted_by)
    select new.id, m.user_id, new.uploaded_by
    from public.family_memberships m
    where m.space_id = new.space_id and m.user_id <> new.uploaded_by
    on conflict (photo_id, grantee_user_id) do nothing;
  end if;
  return new;
end;
$$;

create trigger photos_family_share_snapshot
  after insert or update of visibility on public.photos
  for each row execute function public.materialize_family_photo_share();

-- Join by invite code. Direct inserts into family_memberships are owner-only,
-- so joining uses this RPC with the space's invite_code.
create or replace function public.join_family_space(p_invite_code uuid)
returns uuid
language plpgsql security definer
set search_path = public
as $$
declare
  v_space_id uuid;
begin
  select id into v_space_id from public.family_spaces where invite_code = p_invite_code;
  if v_space_id is null then
    raise exception 'invalid_invite_code';
  end if;
  insert into public.family_memberships (space_id, user_id, role)
  values (v_space_id, auth.uid(), 'member')
  on conflict (space_id, user_id) do nothing;
  return v_space_id;
end;
$$;

-- Extend the signup trigger from 0002_profiles.sql: also fill display_name
-- (from signup metadata, else the email prefix). The trigger itself
-- (on_auth_user_created) already exists and keeps pointing here.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1)))
  on conflict (id) do nothing;
  return new;
end;
$$;

-- Only the trigger may run it.
revoke execute on function public.handle_new_user() from public, anon, authenticated;
