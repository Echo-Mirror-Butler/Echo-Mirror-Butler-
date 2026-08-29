/**
 * Schedule the settle-leaderboard-rewards Edge Function via pg_cron.
 *
 * Runs every Monday at 01:00 UTC to settle weekly leaderboard payouts
 * for the previous week's top earners. The timing ensures:
 * - The week boundary (Monday 00:00 UTC) has passed
 * - Settlement bonuses don't interfere with the new week's leaderboard
 *
 * The function queries leaderboard_weekly (which calculates earnings
 * from the current Monday onwards), determines the previous week's
 * cutoff via getSettlementWeekStart(), and pays out ranks 1-10.
 *
 * See settle-leaderboard-rewards/index.ts for payout tiers:
 * - Rank 1: 100 ECHO
 * - Rank 2: 75 ECHO
 * - Rank 3: 50 ECHO
 * - Ranks 4-10: 25 ECHO each
 *
 * Idempotency is enforced via UNIQUE INDEX on (user_id, reason)
 * in migration 20260828000000_add_leaderboard_reward_idempotency.sql.
 *
 * Follows the same pattern as send-daily-reminder scheduling
 * (see 20260726000003_schedule_daily_reminder_push.sql).
 */

-- Ensure the pg_cron extension is available (idempotent)
create extension if not exists pg_cron;

do $migration$
begin
  -- Only schedule if not already present (idempotent)
  if not exists (
    select 1
    from cron.job
    where jobname = 'settle-leaderboard-rewards'
  ) then
    perform cron.schedule(
      'settle-leaderboard-rewards',
      '0 1 * * 1',  -- every Monday at 01:00 UTC
      $$select net.http_post(
        url := current_setting('app.settings.supabase_url') || '/functions/v1/settle-leaderboard-rewards',
        headers := jsonb_build_object(
          'Authorization',
          'Bearer ' || current_setting('app.settings.service_role_key'),
          'Content-Type',
          'application/json'
        )
      )$$
    );
  end if;
end
$migration$;
