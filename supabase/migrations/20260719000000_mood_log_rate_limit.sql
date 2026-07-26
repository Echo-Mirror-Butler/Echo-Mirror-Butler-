-- Migration: Server-side rate limit on mood log creation (max 10 logs per user per hour)
-- Issue #565
--
-- log_entries is inserted directly by the Flutter client (no server endpoint sits in
-- front of it), so the only place a limit can be enforced without being bypassable by a
-- modified client is a trigger on the table itself. Reuses the existing
-- public.check_rate_limit() helper (added in 20260530120000_add_rate_limits_and_transfer_rpc.sql
-- for send-echo) so all rate-limited actions in this project share one accounting table.

create or replace function public.enforce_mood_log_rate_limit()
returns trigger
language plpgsql
as $$
declare
  v_allowed boolean;
  v_retry_after_seconds int;
begin
  v_allowed := public.check_rate_limit(new.user_id, 'mood_log', 10, 1.0);

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
      detail = 'Maximum 10 mood log entries per user per hour exceeded',
      hint = format('Retry after %s seconds', v_retry_after_seconds);
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_mood_log_rate_limit on public.log_entries;

create trigger trg_enforce_mood_log_rate_limit
  before insert on public.log_entries
  for each row
  execute function public.enforce_mood_log_rate_limit();
