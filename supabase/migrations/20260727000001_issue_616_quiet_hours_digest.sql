-- ============================================================
-- Issue #616 — notification digest frequency & quiet-hours control
--
-- Adds per-user quiet-hours preferences and a digest-frequency mode for
-- lower-priority notifications (e.g. mood-comment notifications), plus a
-- pending_notifications queue so notifications suppressed during quiet
-- hours are delivered afterwards rather than dropped.
--
-- `profiles.timezone` already exists (migration 20260526100000).
-- ============================================================

-- ── Preference columns on profiles ────────────────────────────
alter table public.profiles
  add column if not exists quiet_hours_enabled boolean not null default false,
  -- Local wall-clock times (HH:MM, 24h) in the user's profiles.timezone.
  add column if not exists quiet_hours_start text not null default '22:00',
  add column if not exists quiet_hours_end   text not null default '08:00',
  -- Digest frequency for lower-priority notification types.
  -- 'immediately' = send as they happen; 'daily' = batch into one daily summary.
  add column if not exists mood_comment_digest_mode text not null default 'immediately'
    check (mood_comment_digest_mode in ('immediately', 'daily'));

-- ── Pending-notification queue ────────────────────────────────
-- Rows written when a send is suppressed during quiet hours (or deferred
-- for a daily digest). A scheduled job (deliver-pending-notifications)
-- picks up rows whose scheduled_for <= now() and delivered = false.
create table if not exists public.pending_notifications (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  -- Notification category, e.g. 'daily_reminder' | 'mood_comment'.
  type          text not null,
  title         text not null,
  body          text not null,
  url           text,
  -- Optional extra payload (e.g. comment ids for a batched digest).
  payload       jsonb not null default '{}',
  -- When the notification becomes eligible for delivery (UTC).
  scheduled_for timestamptz not null default now(),
  delivered     boolean not null default false,
  delivered_at  timestamptz,
  created_at    timestamptz not null default now()
);

create index if not exists idx_pending_notifications_due
  on public.pending_notifications(scheduled_for)
  where delivered = false;

create index if not exists idx_pending_notifications_user
  on public.pending_notifications(user_id);

alter table public.pending_notifications enable row level security;

-- Users may read their own queued notifications (e.g. an in-app inbox).
-- Rows are written / marked delivered by edge functions using the service
-- role, which bypasses RLS, so no client insert/update policy is needed.
do $$
begin
  create policy "Users can read own pending notifications"
    on public.pending_notifications for select
    using (auth.uid() = user_id);
exception
  when duplicate_object then null;
end $$;

-- ============================================================
-- Scheduled delivery of queued notifications.
--
-- Deploy manually after setting app.settings.supa_url and
-- app.settings.service_key (mirrors the send-weekly-digest pattern):
--
--   select cron.schedule(
--     'deliver-pending-notifications',
--     '*/5 * * * *',
--     $$
--     select net.http_post(
--       url := current_setting('app.settings.supa_url') || '/functions/v1/deliver-pending-notifications',
--       headers := jsonb_build_object(
--         'Content-Type', 'application/json',
--         'Authorization', 'Bearer ' || current_setting('app.settings.service_key')
--       )
--     )
--     $$
--   );
-- ============================================================
