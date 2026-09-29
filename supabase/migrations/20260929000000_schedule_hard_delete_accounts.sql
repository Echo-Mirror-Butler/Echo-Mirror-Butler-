-- Run the soft-deleted account purge every day after the grace period can expire.

create extension if not exists pg_cron;
create extension if not exists pg_net;

do $migration$
begin
  if not exists (
    select 1 from cron.job where jobname = 'hard-delete-expired-accounts'
  ) then
    perform cron.schedule(
      'hard-delete-expired-accounts',
      '0 2 * * *',
      $$select net.http_post(
        url := current_setting('app.settings.supabase_url') || '/functions/v1/hard-delete-accounts',
        headers := jsonb_build_object(
          'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
          'Content-Type', 'application/json'
        )
      )$$
    );
  end if;
end
$migration$;