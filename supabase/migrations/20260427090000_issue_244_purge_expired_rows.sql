create extension if not exists pg_cron;

do $migration$
begin
  if not exists (
    select 1
    from cron.job
    where jobname = 'purge-expired-rows'
  ) then
    perform cron.schedule(
      'purge-expired-rows',
      '0 * * * *',
      $cleanup$
        delete from public.mood_pins
        where expires_at < now();

        delete from public.video_sessions
        where expires_at < now()
          and is_active = false;

        delete from public.stories
        where expires_at < now();

        delete from public.video_posts
        where expires_at < now();
      $cleanup$
    );
  end if;
end
$migration$;
