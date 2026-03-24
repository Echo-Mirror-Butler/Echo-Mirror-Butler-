-- ============================================================
-- Issue #84: align Supabase application tables and RLS policies
-- ============================================================

-- Ensure column defaults and nullability match the migration brief.
alter table public.mood_comment_notifications
  alter column comment_text drop not null,
  alter column sentiment drop not null;

alter table public.scheduled_sessions
  alter column host_name drop not null,
  alter column title drop not null;

alter table public.video_sessions
  alter column host_name drop not null;

-- Helpful indexes for owner-scoped tables under stricter RLS.
create index if not exists idx_video_sessions_host on public.video_sessions(host_id);
create index if not exists idx_scheduled_sessions_host on public.scheduled_sessions(host_id);
create index if not exists idx_stories_user on public.stories(user_id);

-- Rebuild policies so they line up with the issue's access rules:
-- own data only except mood_pins, video_posts, and mood_pin_comments feed access.

drop policy if exists "Users can read own log entries" on public.log_entries;
drop policy if exists "Users can insert own log entries" on public.log_entries;
drop policy if exists "Users can update own log entries" on public.log_entries;
drop policy if exists "Users can delete own log entries" on public.log_entries;

create policy "Users can read own log entries"
  on public.log_entries for select
  using (auth.uid() = user_id);

create policy "Users can insert own log entries"
  on public.log_entries for insert
  with check (auth.uid() = user_id);

create policy "Users can update own log entries"
  on public.log_entries for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete own log entries"
  on public.log_entries for delete
  using (auth.uid() = user_id);

drop policy if exists "Anyone can read mood pins" on public.mood_pins;
drop policy if exists "Authenticated users can create mood pins" on public.mood_pins;

create policy "Anyone can read mood pins"
  on public.mood_pins for select
  using (true);

create policy "Authenticated users can create mood pins"
  on public.mood_pins for insert
  with check (auth.role() = 'authenticated');

drop policy if exists "Anyone can read comments" on public.mood_pin_comments;
drop policy if exists "Authenticated users can add comments" on public.mood_pin_comments;
drop policy if exists "Users can delete own comments" on public.mood_pin_comments;

create policy "Anyone can read comments"
  on public.mood_pin_comments for select
  using (true);

create policy "Authenticated users can add comments"
  on public.mood_pin_comments for insert
  with check (auth.uid() = user_id);

create policy "Users can delete own comments"
  on public.mood_pin_comments for delete
  using (auth.uid() = user_id);

drop policy if exists "Users can read own notifications" on public.mood_comment_notifications;
drop policy if exists "Users can update own notifications" on public.mood_comment_notifications;

create policy "Users can read own notifications"
  on public.mood_comment_notifications for select
  using (auth.uid() = user_id);

create policy "Users can update own notifications"
  on public.mood_comment_notifications for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Anyone can read active sessions" on public.video_sessions;
drop policy if exists "Authenticated users can create sessions" on public.video_sessions;
drop policy if exists "Host can update own sessions" on public.video_sessions;

create policy "Hosts can read own sessions"
  on public.video_sessions for select
  using (auth.uid() = host_id);

create policy "Authenticated users can create sessions"
  on public.video_sessions for insert
  with check (auth.uid() = host_id);

create policy "Hosts can update own sessions"
  on public.video_sessions for update
  using (auth.uid() = host_id)
  with check (auth.uid() = host_id);

create policy "Hosts can delete own sessions"
  on public.video_sessions for delete
  using (auth.uid() = host_id);

drop policy if exists "Anyone can read scheduled sessions" on public.scheduled_sessions;
drop policy if exists "Authenticated users can create scheduled sessions" on public.scheduled_sessions;
drop policy if exists "Host can update own scheduled sessions" on public.scheduled_sessions;

create policy "Hosts can read own scheduled sessions"
  on public.scheduled_sessions for select
  using (auth.uid() = host_id);

create policy "Authenticated users can create scheduled sessions"
  on public.scheduled_sessions for insert
  with check (auth.uid() = host_id);

create policy "Hosts can update own scheduled sessions"
  on public.scheduled_sessions for update
  using (auth.uid() = host_id)
  with check (auth.uid() = host_id);

create policy "Hosts can delete own scheduled sessions"
  on public.scheduled_sessions for delete
  using (auth.uid() = host_id);

drop policy if exists "Anyone can read active stories" on public.stories;
drop policy if exists "Authenticated users can create stories" on public.stories;
drop policy if exists "Users can update own stories" on public.stories;
drop policy if exists "Users can delete own stories" on public.stories;

create policy "Users can read own stories"
  on public.stories for select
  using (auth.uid() = user_id);

create policy "Authenticated users can create stories"
  on public.stories for insert
  with check (auth.uid() = user_id);

create policy "Users can update own stories"
  on public.stories for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete own stories"
  on public.stories for delete
  using (auth.uid() = user_id);

drop policy if exists "Anyone can read video posts" on public.video_posts;
drop policy if exists "Authenticated users can create video posts" on public.video_posts;

create policy "Anyone can read video posts"
  on public.video_posts for select
  using (true);

create policy "Authenticated users can create video posts"
  on public.video_posts for insert
  with check (auth.role() = 'authenticated');
