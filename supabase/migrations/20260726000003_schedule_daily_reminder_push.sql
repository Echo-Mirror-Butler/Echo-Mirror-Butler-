/**
 * Schedule the send-daily-reminder Edge Function via pg_cron.
 *
 * Runs every 5 minutes (the function filters to subscriptions whose
 * reminder_time is within ±5 minutes of the current UTC time).
 *
 * Follows the same pattern as the existing purge-expired-rows cron job
 * (see 20260427090000_issue_244_purge_expired_rows.sql).
 */

-- Ensure the pg_cron extension is available (idempotent)
create extension if not exists pg_cron;

do $migration$
begin
  -- Only schedule if not already present (idempotent)
  if not exists (
    select 1
    from cron.job
    where jobname = 'send-daily-reminder'
  ) then
    perform cron.schedule(
      'send-daily-reminder',
      '*/5 * * * *',  -- every 5 minutes
      $$select net.http_post(
        url := current_setting('app.settings.supabase_url') || '/functions/v1/send-daily-reminder',
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