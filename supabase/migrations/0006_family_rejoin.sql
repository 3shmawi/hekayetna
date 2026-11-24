-- Rejoin revocation: a member REMOVED by the owner cannot rejoin with the
-- unchanged invite code. A member who leaves on their own can.
--
-- Model: removal is an explicit owner action through remove_family_member
-- (security definer). It records a block row and deletes the membership.
-- join_family_space refuses a blocked user. The owner can lift a block by
-- deleting the block row (owner-only policy) and sharing the code again.
--
-- A direct SQL delete of a membership (owner via the dashboard) does NOT
-- create a block; use the RPC, which is what the app does.

create table public.family_membership_removals (
  space_id uuid not null references public.family_spaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  removed_by uuid not null references auth.users(id),
  removed_at timestamptz not null default now(),
  primary key (space_id, user_id)
);

alter table public.family_membership_removals enable row level security;

-- Only the owner can see blocks or lift them. Ordinary members never read
-- this table; join_family_space checks it server-side as definer.
create policy removals_select on public.family_membership_removals for select using (
  public.is_space_owner(space_id)
);
create policy removals_delete on public.family_membership_removals for delete using (
  public.is_space_owner(space_id)
);
-- No insert/update policies: blocks are written only by remove_family_member.

create or replace function public.remove_family_member(p_membership_id uuid)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  v_space uuid;
  v_user uuid;
begin
  select space_id, user_id into v_space, v_user
  from public.family_memberships where id = p_membership_id;
  if v_space is null then
    raise exception 'membership_not_found';
  end if;
  if not public.is_space_owner(v_space) then
    raise exception 'not_owner';
  end if;
  if v_user = auth.uid() then
    raise exception 'cannot_remove_self';
  end if;
  insert into public.family_membership_removals (space_id, user_id, removed_by)
  values (v_space, v_user, auth.uid())
  on conflict (space_id, user_id) do nothing;
  delete from public.family_memberships where id = p_membership_id;
end;
$$;

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
