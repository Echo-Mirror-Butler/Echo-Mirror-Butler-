-- Migration: Server-side rate limits on mood pin comments and pin drops
-- Issue #588
--
-- Reuses the existing public.check_rate_limit() helper (added in
-- 20260530120000_add_rate_limits_and_transfer_rpc.sql) following the same pattern
-- as the mood-log rate-limit trigger in 20260719000000_mood_log_rate_limit.sql.
--
-- Limits:
--   mood_pin_comment: 20 per user per hour (comments are lightweight, low spam risk)
--   mood_pin_drop:    10 per user per hour (consistent with mood_log limit)

-- ── Mood pin comment rate limit ────────────────────────────────────────────────

create or replace function public.enforce_mood_pin_comment_rate_limit()
returns trigger
language plpgsql
as $$
declare
  v_allowed boolean;
  v_retry_after_seconds int;
begin
  v_allowed := public.check_rate_limit(new.user_id, 'mood_pin_comment', 20, 1.0);

  if not v_allowed then
    v_retry_after_seconds := greatest(
      1,
      ceil(extract(epoch from (date_trunc('hour', now()) + interval '1 hour' - now())))::int
    );

    raise sqlstate 'PT429' using
      message = json_build_object(
        'error', 'rate_limit_exceeded',
        'retry_after_seconds', v_retry_after_seconds
      )::text,
      detail = 'Maximum 20 mood pin comments per user per hour exceeded',
      hint = format('Retry after %s seconds', v_retry_after_seconds);
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_mood_pin_comment_rate_limit on public.mood_pin_comments;

create trigger trg_enforce_mood_pin_comment_rate_limit
  before insert on public.mood_pin_comments
  for each row
  execute function public.enforce_mood_pin_comment_rate_limit();

-- ── Mood pin drop rate limit ───────────────────────────────────────────────────
--
-- mood_pins has no user_id column (pins are anonymous), so we look up the user
-- from user_mood_pins which is written in the same transaction by the client.

create or replace function public.enforce_mood_pin_drop_rate_limit()
returns trigger
language plpgsql
as $$
declare
  v_user_id uuid;
  v_allowed boolean;
  v_retry_after_seconds int;
begin
  -- Resolve the dropping user from the user_mood_pins table
  select ump.user_id into v_user_id
  from public.user_mood_pins ump
  where ump.mood_pin_id = new.id
  limit 1;

  if v_user_id is null then
    -- If we can't resolve the user, allow the insert (anon drop or missing link)
    return new;
  end if;

  v_allowed := public.check_rate_limit(v_user_id, 'mood_pin_drop', 10, 1.0);

  if not v_allowed then
    v_retry_after_seconds := greatest(
      1,
      ceil(extract(epoch from (date_trunc('hour', now()) + interval '1 hour' - now())))::int
    );

    raise sqlstate 'PT429' using
      message = json_build_object(
        'error', 'rate_limit_exceeded',
        'retry_after_seconds', v_retry_after_seconds
      )::text,
      detail = 'Maximum 10 mood pin drops per user per hour exceeded',
      hint = format('Retry after %s seconds', v_retry_after_seconds);
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_mood_pin_drop_rate_limit on public.mood_pins;

create trigger trg_enforce_mood_pin_drop_rate_limit
  before insert on public.mood_pins
  for each row
  execute function public.enforce_mood_pin_drop_rate_limit();
