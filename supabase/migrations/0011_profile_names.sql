-- Profile names are never derived from the email address.
-- Migration 0003 filled display_name with the email prefix when signup gave
-- no name, and the member list shows that name to the whole family. From now
-- on a new profile gets only a name the person chose (signup metadata,
-- trimmed to 40 characters) and otherwise stays empty until they set one
-- (spec 06, "What does the family call you?").
-- Existing rows are not rewritten here: a name a person already set cannot be
-- told apart from an email prefix in SQL.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    nullif(left(btrim(coalesce(new.raw_user_meta_data ->> 'display_name', '')), 40), '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- Only the trigger may run it.
revoke execute on function public.handle_new_user() from public, anon, authenticated;

-- A chosen name is 1-40 characters after trimming (the table keeps the older
-- 80-character limit so existing rows stay valid).
create or replace function public.set_my_display_name(p_name text)
returns text
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_name text := btrim(coalesce(p_name, ''));
begin
  if char_length(v_name) < 1 or char_length(v_name) > 40 then
    raise exception 'invalid_display_name' using errcode = '22023';
  end if;
  update public.profiles set display_name = v_name, updated_at = now()
  where id = auth.uid();
  return v_name;
end;
$$;

revoke execute on function public.set_my_display_name(text) from public, anon;
grant execute on function public.set_my_display_name(text) to authenticated;
