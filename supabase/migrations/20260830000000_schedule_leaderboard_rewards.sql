-- Schedule the settle-leaderboard-rewards Edge Function via pg_cron.
--
-- The leaderboard's "this week" window is defined by date_trunc('week', now() AT TIME ZONE 'UTC'),
-- which resets every Monday at 00:00 UTC. This job therefore runs at Monday 00:05 UTC,
-- giving the weekly window time to reset before settlement executes.

create extension if not exists pg_cron;

do $migration$
begin
  if not exists (
    select 1
    from cron.job
    where jobname = 'settle-leaderboard-rewards'
  ) then
    perform cron.schedule(
      'settle-leaderboard-rewards',
      '5 0 * * 1',
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
