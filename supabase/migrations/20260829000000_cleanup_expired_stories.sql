-- Cleanup expired stories after a short grace period.
--
-- Design choice: we do not delete immediately when expires_at is reached.
-- We wait 30 minutes after expiry before purging the row and its Storage objects,
-- which gives us a bounded recovery window for moderation or user complaints.
--
-- This job is idempotent: it safely re-runs with no error if a story was already
-- removed in a previous run or its storage object is already gone.

create extension if not exists pg_cron;

do $migration$
begin
  if not exists (
    select 1
    from cron.job
    where jobname = 'cleanup-expired-stories'
  ) then
    perform cron.schedule(
      'cleanup-expired-stories',
      '*/15 * * * *',
      $$select net.http_post(
        url := current_setting('app.settings.supabase_url') || '/functions/v1/cleanup-expired-stories',
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
