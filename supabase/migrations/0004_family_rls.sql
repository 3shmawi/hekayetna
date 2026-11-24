-- Family Stories & Memory Map - row-level security
-- Migration 4: RLS on every table. Server-side authorization lives here and
-- nowhere else; the UI only reflects it. Rules:
--  * Membership never grants blanket content access; stories are gated per story.
--  * Nobody can grant themselves access: story_recipients inserts require the
--    grantor to be the story creator and the grantee to be a space member.
--  * Removing a membership revokes all future access immediately (all checks
--    read live membership rows).

alter table public.profiles           enable row level security;
alter table public.family_spaces      enable row level security;
alter table public.family_memberships enable row level security;
alter table public.persons            enable row level security;
alter table public.relationships      enable row level security;
alter table public.stories            enable row level security;
alter table public.story_narrators    enable row level security;
alter table public.story_people       enable row level security;
alter table public.photos             enable row level security;
alter table public.photo_people       enable row level security;
alter table public.story_photos       enable row level security;
alter table public.story_recipients   enable row level security;
alter table public.photo_recipients   enable row level security;

-- Replace the self-only profile policies from 0002_profiles.sql with the
-- family-aware ones below (family members see each other's names).
drop policy if exists "Users read their own profile" on public.profiles;
drop policy if exists "Users update their own profile" on public.profiles;

-- ---------- profiles ----------
-- Visible to yourself and to members of spaces you share (so members can see
-- each other's names in the directory and member list).
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select using (
  id = auth.uid()
  or exists (
    select 1 from public.family_memberships mine
    join public.family_memberships theirs on theirs.space_id = mine.space_id
    where mine.user_id = auth.uid() and theirs.user_id = profiles.id
  )
);
drop policy if exists profiles_insert on public.profiles;
create policy profiles_insert on public.profiles for insert with check (id = auth.uid());
drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());

-- ---------- family_spaces ----------
drop policy if exists spaces_select on public.family_spaces;
create policy spaces_select on public.family_spaces for select using (public.is_space_member(id));
drop policy if exists spaces_insert on public.family_spaces;
create policy spaces_insert on public.family_spaces for insert with check (created_by = auth.uid());
drop policy if exists spaces_update on public.family_spaces;
create policy spaces_update on public.family_spaces for update using (public.is_space_owner(id));
drop policy if exists spaces_delete on public.family_spaces;
create policy spaces_delete on public.family_spaces for delete using (public.is_space_owner(id));

-- ---------- family_memberships ----------
-- Members see the member list of their own spaces.
drop policy if exists memberships_select on public.family_memberships;
create policy memberships_select on public.family_memberships for select using (
  public.is_space_member(space_id)
);
-- Direct inserts: only the space owner adds people. Everyone else joins
-- through the join_family_space(invite_code) RPC (security definer).
drop policy if exists memberships_insert on public.family_memberships;
create policy memberships_insert on public.family_memberships for insert with check (
  public.is_space_owner(space_id) and user_id <> auth.uid()
);
-- Role changes and person links: owner only. A member cannot promote
-- themselves because they cannot pass this policy on their own row.
drop policy if exists memberships_update on public.family_memberships;
create policy memberships_update on public.family_memberships for update using (
  public.is_space_owner(space_id)
);
-- Leave your own space, or the owner removes someone. Removal deletes the row,
-- so every access check above stops passing for that user from that moment.
drop policy if exists memberships_delete on public.family_memberships;
create policy memberships_delete on public.family_memberships for delete using (
  user_id = auth.uid() or public.is_space_owner(space_id)
);

-- ---------- persons ----------
-- Directory data (names, approximate dates, bios, relationships) is shared
-- with space members. Content (stories, photos) stays gated per item.
drop policy if exists persons_select on public.persons;
create policy persons_select on public.persons for select using (public.is_space_member(space_id));
drop policy if exists persons_insert on public.persons;
create policy persons_insert on public.persons for insert with check (
  public.is_space_member(space_id) and created_by = auth.uid()
);
drop policy if exists persons_update on public.persons;
create policy persons_update on public.persons for update using (
  created_by = auth.uid() or linked_user_id = auth.uid() or public.is_space_owner(space_id)
);
drop policy if exists persons_delete on public.persons;
create policy persons_delete on public.persons for delete using (
  created_by = auth.uid() or public.is_space_owner(space_id)
);

-- ---------- relationships ----------
drop policy if exists relationships_select on public.relationships;
create policy relationships_select on public.relationships for select using (public.is_space_member(space_id));
drop policy if exists relationships_insert on public.relationships;
create policy relationships_insert on public.relationships for insert with check (
  public.is_space_member(space_id) and created_by = auth.uid()
);
-- Confirm or correct: the creator, the space owner, or the member linked to
-- either side of the relationship. Never automatic, never name-matching.
drop policy if exists relationships_update on public.relationships;
create policy relationships_update on public.relationships for update using (
  created_by = auth.uid()
  or public.is_space_owner(space_id)
  or exists (
    select 1 from public.persons p
    where p.id in (relationships.person_id, relationships.related_person_id)
      and p.linked_user_id = auth.uid()
  )
);
drop policy if exists relationships_delete on public.relationships;
create policy relationships_delete on public.relationships for delete using (
  created_by = auth.uid() or public.is_space_owner(space_id)
);

-- ---------- stories ----------
-- The single access rule for reading a story row.
drop policy if exists stories_select on public.stories;
create policy stories_select on public.stories for select using (public.can_access_story(id));
drop policy if exists stories_insert on public.stories;
create policy stories_insert on public.stories for insert with check (
  public.is_space_member(space_id) and created_by = auth.uid()
);
-- Only the creator edits or deletes their story. Ownership of the space does
-- not override story privacy.
drop policy if exists stories_update on public.stories;
create policy stories_update on public.stories for update using (created_by = auth.uid()) with check (created_by = auth.uid());
drop policy if exists stories_delete on public.stories;
create policy stories_delete on public.stories for delete using (created_by = auth.uid());

-- ---------- story join tables ----------
-- Readable exactly when the story itself is readable, so narrators, mentioned
-- people, and linked photos never leak an inaccessible story's existence.
drop policy if exists story_narrators_select on public.story_narrators;
create policy story_narrators_select on public.story_narrators for select using (public.can_access_story(story_id));
drop policy if exists story_narrators_insert on public.story_narrators;
create policy story_narrators_insert on public.story_narrators for insert with check (
  exists (select 1 from public.stories s where s.id = story_id and s.created_by = auth.uid())
);
drop policy if exists story_narrators_delete on public.story_narrators;
create policy story_narrators_delete on public.story_narrators for delete using (
  exists (select 1 from public.stories s where s.id = story_id and s.created_by = auth.uid())
);

drop policy if exists story_people_select on public.story_people;
create policy story_people_select on public.story_people for select using (public.can_access_story(story_id));
drop policy if exists story_people_insert on public.story_people;
create policy story_people_insert on public.story_people for insert with check (
  exists (select 1 from public.stories s where s.id = story_id and s.created_by = auth.uid())
);
drop policy if exists story_people_delete on public.story_people;
create policy story_people_delete on public.story_people for delete using (
  exists (select 1 from public.stories s where s.id = story_id and s.created_by = auth.uid())
);

drop policy if exists story_photos_select on public.story_photos;
create policy story_photos_select on public.story_photos for select using (public.can_access_story(story_id));
drop policy if exists story_photos_insert on public.story_photos;
create policy story_photos_insert on public.story_photos for insert with check (
  exists (select 1 from public.stories s where s.id = story_id and s.created_by = auth.uid())
);
drop policy if exists story_photos_delete on public.story_photos;
create policy story_photos_delete on public.story_photos for delete using (
  exists (select 1 from public.stories s where s.id = story_id and s.created_by = auth.uid())
);

-- ---------- photos ----------
-- Uploader, plus members holding a grant from the family-share snapshot.
-- Linking to a story never widens this: the photo keeps its own audience.
drop policy if exists photos_select on public.photos;
create policy photos_select on public.photos for select using (public.can_access_photo(id));
drop policy if exists photos_insert on public.photos;
create policy photos_insert on public.photos for insert with check (
  public.is_space_member(space_id) and uploaded_by = auth.uid()
);
drop policy if exists photos_update on public.photos;
create policy photos_update on public.photos for update using (uploaded_by = auth.uid());
drop policy if exists photos_delete on public.photos;
create policy photos_delete on public.photos for delete using (uploaded_by = auth.uid());

-- Tags of people in a photo follow the photo's own visibility.
drop policy if exists photo_people_select on public.photo_people;
create policy photo_people_select on public.photo_people for select using (public.can_access_photo(photo_id));
drop policy if exists photo_people_insert on public.photo_people;
create policy photo_people_insert on public.photo_people for insert with check (
  exists (select 1 from public.photos p where p.id = photo_id and p.uploaded_by = auth.uid())
);
drop policy if exists photo_people_delete on public.photo_people;
create policy photo_people_delete on public.photo_people for delete using (
  exists (select 1 from public.photos p where p.id = photo_id and p.uploaded_by = auth.uid())
);

-- ---------- story_recipients ----------
-- Grantees see their own grants; the creator sees all grants on their stories.
drop policy if exists story_recipients_select on public.story_recipients;
create policy story_recipients_select on public.story_recipients for select using (
  grantee_user_id = auth.uid()
  or exists (select 1 from public.stories s where s.id = story_id and s.created_by = auth.uid())
);
-- Only the story creator grants, only to current members of the story's
-- space, and never to themselves (a grant to the creator is meaningless and
-- would mask privilege mistakes).
drop policy if exists story_recipients_insert on public.story_recipients;
create policy story_recipients_insert on public.story_recipients for insert with check (
  granted_by = auth.uid()
  and grantee_user_id <> auth.uid()
  and exists (
    select 1 from public.stories s
    where s.id = story_id
      and s.created_by = auth.uid()
      and public.is_space_member(s.space_id)
  )
  and exists (
    select 1 from public.family_memberships gm
    join public.stories s on s.id = story_id
    where gm.space_id = s.space_id and gm.user_id = grantee_user_id
  )
);
-- Revocation by the creator (or the grantee removing themselves).
drop policy if exists story_recipients_delete on public.story_recipients;
create policy story_recipients_delete on public.story_recipients for delete using (
  grantee_user_id = auth.uid()
  or exists (select 1 from public.stories s where s.id = story_id and s.created_by = auth.uid())
);

-- ---------- photo_recipients ----------
-- Same rules as story_recipients, with the uploader in the creator role.
drop policy if exists photo_recipients_select on public.photo_recipients;
create policy photo_recipients_select on public.photo_recipients for select using (
  grantee_user_id = auth.uid()
  or exists (select 1 from public.photos p where p.id = photo_id and p.uploaded_by = auth.uid())
);
drop policy if exists photo_recipients_insert on public.photo_recipients;
create policy photo_recipients_insert on public.photo_recipients for insert with check (
  granted_by = auth.uid()
  and grantee_user_id <> auth.uid()
  and exists (
    select 1 from public.photos p
    where p.id = photo_id
      and p.uploaded_by = auth.uid()
      and public.is_space_member(p.space_id)
  )
  and exists (
    select 1 from public.family_memberships gm
    join public.photos p on p.id = photo_id
    where gm.space_id = p.space_id and gm.user_id = grantee_user_id
  )
);
drop policy if exists photo_recipients_delete on public.photo_recipients;
create policy photo_recipients_delete on public.photo_recipients for delete using (
  grantee_user_id = auth.uid()
  or exists (select 1 from public.photos p where p.id = photo_id and p.uploaded_by = auth.uid())
);
