-- Family Stories & Memory Map - private storage
-- Migration 5: buckets and storage RLS. Buckets are private; clients read
-- through short-lived signed URLs only. A signed URL, once issued, stays
-- usable by its holder until it expires even if access is revoked a second
-- later. That residual access cannot be revoked, so the app issues URLs with
-- a short TTL (default 15 minutes) and re-mints on demand instead of treating
-- expiry as revocation.
--
-- Path conventions (first segment is always the family space id; the second
-- segment of member uploads is always the uploader's user id):
--   story-audio/{space_id}/{uploader_id}/{story_id}/{file}.m4a
--   family-photos/{space_id}/{uploader_id}/{photo_id}/{file}.jpg|jpeg|png|heic|webp
--   family-photos/{space_id}/persons/{person_id}/{file}.jpg|...  (directory avatars)
--
-- Why the uploader segment: audio/photo files are uploaded BEFORE their
-- metadata row exists (upload-then-save flow), so insert-time checks cannot
-- look up story ownership. Namespacing every upload under auth.uid() means no
-- member can occupy, overwrite, or enumerate another member's staging paths,
-- and the object owner can always find and delete their own orphan objects if
-- the metadata insert fails afterwards. There is intentionally NO update
-- policy: retries delete-then-insert, never silently replace.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('story-audio', 'story-audio', false, 104857600, -- 100 MB per recording
   array['audio/m4a', 'audio/mp4', 'audio/x-m4a', 'audio/aac', 'audio/mpeg', 'audio/wav', 'audio/webm']),
  ('family-photos', 'family-photos', false, 20971520, -- 20 MB per photo
   array['image/jpeg', 'image/png', 'image/heic', 'image/heif', 'image/webp'])
on conflict (id) do nothing;

-- Parse helpers: a bad or unexpected path must deny, never error open.
create or replace function public.storage_space_id(p_name text)
returns uuid
language plpgsql stable
set search_path = public
as $$
begin
  return ((storage.foldername(p_name))[1])::uuid;
exception when others then
  return null;
end;
$$;

create or replace function public.storage_segment_uuid(p_name text, p_segment int)
returns uuid
language plpgsql stable
set search_path = public
as $$
begin
  return ((storage.foldername(p_name))[p_segment])::uuid;
exception when others then
  return null;
end;
$$;

create or replace function public.storage_segment_text(p_name text, p_segment int)
returns text
language plpgsql stable
set search_path = public
as $$
begin
  return (storage.foldername(p_name))[p_segment];
exception when others then
  return null;
end;
$$;

-- ---------- story-audio ----------
-- Upload: a member of the space, strictly inside their own uploader prefix.
-- The story row does not have to exist yet, but the uploader prefix stops a
-- member from squatting on or clobbering another member's story path.
drop policy if exists audio_insert on storage.objects;
create policy audio_insert on storage.objects for insert to authenticated
with check (
  bucket_id = 'story-audio'
  and public.is_space_member(public.storage_space_id(name))
  and public.storage_segment_text(name, 2) = auth.uid()::text
  and public.storage_segment_uuid(name, 3) is not null
);

-- Read: someone who can access the story the file belongs to, or the object's
-- owner (so the uploader can always find their own files, including orphans
-- whose story row never got created, for cleanup and retry).
drop policy if exists audio_select on storage.objects;
create policy audio_select on storage.objects for select to authenticated
using (
  bucket_id = 'story-audio'
  -- Membership is required even for the owner branch: removal from the space
  -- ends a former member's access to everything in the bucket, including
  -- objects they uploaded themselves (staged or orphaned).
  and public.is_space_member(public.storage_space_id(name))
  and (
    public.can_access_story(public.storage_segment_uuid(name, 3))
    or owner::text = auth.uid()::text
  )
);

-- Delete: the object's owner only. Normally the owner is the story creator;
-- for orphans (story row missing after a failed save) this is what makes
-- cleanup and retry possible.
drop policy if exists audio_delete on storage.objects;
create policy audio_delete on storage.objects for delete to authenticated
using (
  bucket_id = 'story-audio'
  and public.is_space_member(public.storage_space_id(name))
  and owner::text = auth.uid()::text
);

-- ---------- family-photos ----------
-- Avatars: any member may manage directory avatars (the directory is a shared
-- workspace). Memory photos: strictly the uploader's own prefix.
drop policy if exists photo_files_insert on storage.objects;
create policy photo_files_insert on storage.objects for insert to authenticated
with check (
  bucket_id = 'family-photos'
  and public.is_space_member(public.storage_space_id(name))
  and (
    public.storage_segment_text(name, 2) = 'persons'
    or (
      public.storage_segment_text(name, 2) = auth.uid()::text
      and public.storage_segment_uuid(name, 3) is not null
    )
  )
);

-- Person avatars (directory identity): readable by all space members.
-- Memory photos: readable per can_access_photo (uploader, or an explicit
-- photo grant; linking to a story never widens this), plus the object owner
-- for the same orphan-cleanup reason as audio.
drop policy if exists photo_files_select on storage.objects;
create policy photo_files_select on storage.objects for select to authenticated
using (
  bucket_id = 'family-photos'
  and (
    (
      public.storage_segment_text(name, 2) = 'persons'
      and public.is_space_member(public.storage_space_id(name))
    )
    or public.can_access_photo(public.storage_segment_uuid(name, 3))
    or (
      -- Owner branch, still membership-gated: a removed member cannot read
      -- back even their own uploads.
      public.is_space_member(public.storage_space_id(name))
      and owner::text = auth.uid()::text
    )
  )
);

drop policy if exists photo_files_delete on storage.objects;
create policy photo_files_delete on storage.objects for delete to authenticated
using (
  bucket_id = 'family-photos'
  and public.is_space_member(public.storage_space_id(name))
  and (
    public.storage_segment_text(name, 2) = 'persons'
    or owner::text = auth.uid()::text
  )
);
