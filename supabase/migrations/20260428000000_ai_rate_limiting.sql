-- Migration: rate_limit tracking for AI Edge Functions
-- Created: 2026-04-28

-- Create table for tracking AI function rate limits
create table if not exists public.ai_rate_limits (
  user_id uuid not null references auth.users(id) on delete cascade,
  function_name text not null,
  window_start timestamptz not null default date_trunc('hour', now()),
  call_count int not null default 1,
  primary key (user_id, function_name, window_start)
);

-- Enable RLS
alter table public.ai_rate_limits enable row level security;

-- Users can only see their own rate limit entries
create policy "Users can view own rate limits"
  on public.ai_rate_limits
  for select
  using (auth.uid() = user_id);

-- Only the service role can insert/update rate limits (Edge Functions use service role)
create policy "Service role can manage rate limits"
  on public.ai_rate_limits
  for all
  using (auth.role() = 'service_role');

-- Function to check and increment rate limit
-- Returns true if under limit, false if over limit
create or replace function public.check_and_increment_rate_limit(
  p_user_id uuid,
  p_function text,
  p_max_calls int
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
  v_window_start timestamptz := date_trunc('hour', now());
begin
  -- Try to insert or update the rate limit counter
  insert into public.ai_rate_limits (user_id, function_name, window_start, call_count)
  values (p_user_id, p_function, v_window_start, 1)
  on conflict (user_id, function_name, window_start)
  do update set call_count = ai_rate_limits.call_count + 1
  returning call_count into v_count;

  -- Return true if under limit, false if over
  return v_count <= p_max_calls;
end;
$$;

-- Grant execute permission to service role
revoke all on function public.check_and_increment_rate_limit(uuid, text, int) from public;
grant execute on function public.check_and_increment_rate_limit(uuid, text, int) to service_role;
