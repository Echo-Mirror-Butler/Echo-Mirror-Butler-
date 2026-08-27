-- ============================================================
-- Fix weekly digest cron schedule: update from 09:00 to 20:00 UTC (issue #570)
-- The issue specifies Sunday 20:00 UTC for the weekly summary email.
-- ============================================================

-- Remove the old schedule if it exists (created by the 20260628 migration)
select cron.unschedule('send-weekly-digest')
  where exists (
    select 1 from cron.job where jobname = 'send-weekly-digest'
  );

-- Re-schedule at Sunday 20:00 UTC
-- Requires net extension and service role key set as a custom DB parameter.
--
-- Run in Supabase SQL Editor after setting:
--   app.settings.supa_url  = 'https://<project>.supabase.co'
--   app.settings.service_key = '<service_role_key>'
--
-- select cron.schedule(
--   'send-weekly-digest',
--   '0 20 * * 0',
--   $$
--   select net.http_post(
--     url := current_setting('app.settings.supa_url') || '/functions/v1/send-weekly-digest',
--     headers := jsonb_build_object(
--       'Content-Type', 'application/json',
--       'Authorization', 'Bearer ' || current_setting('app.settings.service_key')
--     )
--   )
--   $$
-- );
--
-- Alternatively via Supabase Dashboard → SQL Editor:
--
-- select cron.schedule(
--   'send-weekly-digest',
--   '0 20 * * 0',
--   $$
--   select net.http_post(
--     url := 'https://<project>.supabase.co/functions/v1/send-weekly-digest',
--     headers := '{"Content-Type": "application/json", "Authorization": "Bearer <service_role_key>"}'::jsonb
--   )
--   $$
-- );
