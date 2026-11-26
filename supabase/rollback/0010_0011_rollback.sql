-- Rollback for migrations 0011_profile_names and 0010_invite_codes.
-- NOT a migration: do not put it in supabase/migrations. Run it by hand, in one
-- transaction, only if 0010/0011 must be undone:
--   psql "$DB_URL" -1 -f supabase/rollback/0010_0011_rollback.sql
-- Effects: 0011 undone (handle_new_user back to the 0003 version, which uses the
-- email prefix again; set_my_display_name dropped; names already saved stay).
-- 0010 undone (all short-code functions, trigger, constraint, index and the
-- invite_short_code column dropped). Short codes already shared (QR, WhatsApp)
-- stop working; the UUID invite_code and join_family_space(uuid) are untouched.
-- Rows in family_spaces, memberships and profiles are not deleted.
-- Keep in sync with the inline copy in supabase/tests/upgrade_0010_0011.test.sql
-- (CI runs that copy against a seeded local database).
begin;
  drop function if exists public.set_my_display_name(text);
  create or replace function public.handle_new_user()
  returns trigger language plpgsql security definer set search_path = ''
  as $fn$
  begin
    insert into public.profiles (id, display_name)
    values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1)))
    on conflict (id) do nothing;
    return new;
  end;
  $fn$;
  revoke execute on function public.handle_new_user() from public, anon, authenticated;

  drop function if exists public.rotate_invite_code(uuid);
  drop function if exists public.preview_family_by_code(text);
  drop function if exists public.join_family_space_by_code(text);
  drop function if exists public.normalize_invite_code(text);
  drop trigger if exists family_spaces_short_code on public.family_spaces;
  drop function if exists public.set_invite_short_code();
  alter table public.family_spaces drop constraint if exists family_spaces_invite_short_code_format;
  drop index if exists public.family_spaces_invite_short_code_key;
  alter table public.family_spaces drop column if exists invite_short_code;
  drop function if exists public.generate_short_code();
commit;
