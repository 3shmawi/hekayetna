-- Spec 06: short invite codes (for QR and WhatsApp links), a preview RPC
-- for the join screen, and owner-only code rotation. The UUID
-- join_family_space stays for old links.

-- 7 characters from an alphabet without 0, O, 1, I or L.
create or replace function public.generate_short_code()
returns text
language plpgsql
volatile
set search_path = public
as $$
declare
  v_alphabet constant text := '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  v_code text;
begin
  loop
    v_code := '';
    for i in 1..7 loop
      v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.family_spaces where invite_short_code = v_code);
  end loop;
  return v_code;
end;
$$;
revoke execute on function public.generate_short_code() from public, anon, authenticated;

alter table public.family_spaces add column if not exists invite_short_code text;

-- Backfill existing families, then require and uniquify.
update public.family_spaces
set invite_short_code = public.generate_short_code()
where invite_short_code is null;

alter table public.family_spaces
  alter column invite_short_code set not null;
create unique index if not exists family_spaces_invite_short_code_key
  on public.family_spaces (invite_short_code);
alter table public.family_spaces
  add constraint family_spaces_invite_short_code_format
  check (invite_short_code ~ '^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{7}$');

create or replace function public.set_invite_short_code()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.invite_short_code is null then
    new.invite_short_code := public.generate_short_code();
  end if;
  return new;
end;
$$;
revoke execute on function public.set_invite_short_code() from public, anon, authenticated;

-- A before-insert trigger fills the code, so inserts need not supply one.
-- The NOT NULL check runs after before-triggers, so this is safe.
drop trigger if exists family_spaces_short_code on public.family_spaces;
create trigger family_spaces_short_code
  before insert on public.family_spaces
  for each row execute function public.set_invite_short_code();

-- Uppercase, strip spaces and dashes.
create or replace function public.normalize_invite_code(p_code text)
returns text
language sql
immutable
as $$
  select upper(regexp_replace(coalesce(p_code, ''), '[\s-]', '', 'g'));
$$;

create or replace function public.join_family_space_by_code(p_code text)
returns uuid
language plpgsql security definer
set search_path = public
as $$
declare
  v_code text := public.normalize_invite_code(p_code);
  v_space_id uuid;
begin
  if auth.uid() is null then
    raise exception 'invalid_invite_code';
  end if;
  select id into v_space_id from public.family_spaces where invite_short_code = v_code;
  if v_space_id is null then
    raise exception 'invalid_invite_code';
  end if;
  if exists (
    select 1 from public.family_membership_removals r
    where r.space_id = v_space_id and r.user_id = auth.uid()
  ) then
    raise exception 'member_removed';
  end if;
  insert into public.family_memberships (space_id, user_id, role)
  values (v_space_id, auth.uid(), 'member')
  on conflict (space_id, user_id) do nothing;
  return v_space_id;
end;
$$;
revoke execute on function public.join_family_space_by_code(text) from public, anon;
grant execute on function public.join_family_space_by_code(text) to authenticated;

-- What the confirm screen may show: the family name and a head count.
-- Nothing else, and only for signed-in users.
create or replace function public.preview_family_by_code(p_code text)
returns table (name text, member_count int)
language plpgsql security definer stable
set search_path = public
as $$
declare
  v_code text := public.normalize_invite_code(p_code);
begin
  if auth.uid() is null then
    raise exception 'invalid_invite_code';
  end if;
  return query
    select s.name,
           (select count(*)::int from public.family_memberships m where m.space_id = s.id)
    from public.family_spaces s
    where s.invite_short_code = v_code;
  if not found then
    raise exception 'invalid_invite_code';
  end if;
end;
$$;
revoke execute on function public.preview_family_by_code(text) from public, anon;
grant execute on function public.preview_family_by_code(text) to authenticated;

-- Owner only: new short code and new UUID code; the old ones stop at once.
create or replace function public.rotate_invite_code(p_space uuid)
returns text
language plpgsql security definer
set search_path = public
as $$
declare
  v_new text;
begin
  if not public.is_space_owner(p_space) then
    raise exception 'insufficient_privilege' using errcode = '42501';
  end if;
  v_new := public.generate_short_code();
  update public.family_spaces
  set invite_short_code = v_new,
      invite_code = gen_random_uuid()
  where id = p_space;
  return v_new;
end;
$$;
revoke execute on function public.rotate_invite_code(uuid) from public, anon;
grant execute on function public.rotate_invite_code(uuid) to authenticated;
