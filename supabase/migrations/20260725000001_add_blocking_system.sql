-- Issue #596: follow/friend blocking and mutual-block-aware feed filtering

-- Create user_blocks table
create table if not exists public.user_blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  reason text,
  created_at timestamptz not null default now(),
  unique(blocker_id, blocked_id),
  check (blocker_id != blocked_id)
);

create index if not exists idx_user_blocks_blocker on public.user_blocks(blocker_id);
create index if not exists idx_user_blocks_blocked on public.user_blocks(blocked_id);

alter table public.user_blocks enable row level security;

create policy "Users can view own blocks" on public.user_blocks
  for select using (auth.uid() = blocker_id);

create policy "Users can insert blocks" on public.user_blocks
  for insert with check (auth.uid() = blocker_id);

create policy "Users can delete own blocks" on public.user_blocks
  for delete using (auth.uid() = blocker_id);

-- public.user_follows is created by 20260629000001_social_features.sql, which
-- names the target column following_id. This migration previously re-created
-- the table with a followed_id column; the create was a no-op behind
-- "if not exists", but the index that followed it referenced a column that
-- does not exist and aborted the whole migration run:
--   ERROR: column "followed_id" does not exist (SQLSTATE 42703)
-- All application code reads following_id (follow_repository.dart,
-- follow_model.dart, mood_pin_comment_dialog.dart) and nothing reads
-- followed_id, so social_features owns the schema and the duplicate
-- definition is removed here.
--
-- The one behaviour worth keeping from that block is block-awareness: you
-- should not be able to follow someone you have blocked, or who has blocked
-- you. social_features cannot express this itself because it runs before
-- user_blocks exists, so the policy is replaced here, rewritten against
-- following_id.
create index if not exists idx_user_follows_follower on public.user_follows(follower_id);
create index if not exists idx_user_follows_following on public.user_follows(following_id);

drop policy if exists "users_can_follow" on public.user_follows;

create policy "users_can_follow" on public.user_follows
  for insert with check (
    auth.uid() = follower_id
    and follower_id != following_id
    and not exists (
      select 1 from public.user_blocks
      where (blocker_id = auth.uid() and blocked_id = following_id)
         or (blocker_id = following_id and blocked_id = auth.uid())
    )
  );

-- Create user_friends table
create table if not exists public.user_friends (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  friend_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(user_id, friend_id),
  check (user_id < friend_id)
);

create index if not exists idx_user_friends_user on public.user_friends(user_id);
create index if not exists idx_user_friends_friend on public.user_friends(friend_id);

alter table public.user_friends enable row level security;

create policy "Users can view own friends" on public.user_friends
  for select using (auth.uid() = user_id or auth.uid() = friend_id);

create policy "Users can insert friend relations" on public.user_friends
  for insert with check (auth.uid() in (user_id, friend_id) and not exists (
    select 1 from public.user_blocks where (blocker_id = auth.uid() and blocked_id = (case when user_id = auth.uid() then friend_id else user_id end))
    or (blocker_id = (case when user_id = auth.uid() then friend_id else user_id end) and blocked_id = auth.uid())
  ));

-- Function to block user and remove relationships
create or replace function public.block_user(p_blocked_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_blocker_id uuid := auth.uid();
begin
  if v_blocker_id is null then
    raise exception 'Not authenticated';
  end if;

  if v_blocker_id = p_blocked_id then
    raise exception 'Cannot block yourself';
  end if;

  -- Create block
  insert into public.user_blocks (blocker_id, blocked_id)
  values (v_blocker_id, p_blocked_id)
  on conflict (blocker_id, blocked_id) do nothing;

  -- Remove follows in both directions (column is following_id, per
  -- 20260629000001_social_features.sql)
  delete from public.user_follows
  where (follower_id = v_blocker_id and following_id = p_blocked_id)
    or (follower_id = p_blocked_id and following_id = v_blocker_id);

  -- Remove friendship
  delete from public.user_friends
  where (user_id = v_blocker_id and friend_id = p_blocked_id)
    or (user_id = p_blocked_id and friend_id = v_blocker_id);

  -- Log action
  perform public.log_audit_action('block_user', 'user', p_blocked_id, jsonb_build_object('blocker', v_blocker_id));

  return jsonb_build_object('success', true, 'blocked_id', p_blocked_id);
end;
$$;

-- Function to unblock user
create or replace function public.unblock_user(p_blocked_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  delete from public.user_blocks
  where blocker_id = auth.uid() and blocked_id = p_blocked_id;

  perform public.log_audit_action('unblock_user', 'user', p_blocked_id);

  return jsonb_build_object('success', true);
end;
$$;
