-- ============================================================
-- EchoMirror Butler — Initial Schema
-- Migrated from Serverpod to Supabase
-- ============================================================

-- ============================================================
-- 1. LOG ENTRIES
-- ============================================================
create table public.log_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  date timestamptz not null,
  mood int check (mood between 1 and 5),
  habits jsonb not null default '[]',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_log_entries_user_date on public.log_entries(user_id, date);

alter table public.log_entries enable row level security;

create policy "Users can read own log entries"
  on public.log_entries for select
  using (auth.uid() = user_id);

create policy "Users can insert own log entries"
  on public.log_entries for insert
  with check (auth.uid() = user_id);

create policy "Users can update own log entries"
  on public.log_entries for update
  using (auth.uid() = user_id);

create policy "Users can delete own log entries"
  on public.log_entries for delete
  using (auth.uid() = user_id);

-- ============================================================
-- 2. MOOD PINS (anonymous, publicly readable)
-- ============================================================
create table public.mood_pins (
  id uuid primary key default gen_random_uuid(),
  sentiment text not null,
  grid_lat float8 not null,
  grid_lon float8 not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours')
);

create index idx_mood_pins_expires on public.mood_pins(expires_at);

alter table public.mood_pins enable row level security;

create policy "Anyone can read mood pins"
  on public.mood_pins for select
  using (true);

create policy "Authenticated users can create mood pins"
  on public.mood_pins for insert
  with check (auth.role() = 'authenticated');

-- ============================================================
-- 3. MOOD PIN COMMENTS
-- ============================================================
create table public.mood_pin_comments (
  id uuid primary key default gen_random_uuid(),
  mood_pin_id uuid not null references public.mood_pins(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  text text not null,
  created_at timestamptz not null default now()
);

create index idx_mood_pin_comments_pin on public.mood_pin_comments(mood_pin_id);

alter table public.mood_pin_comments enable row level security;

create policy "Anyone can read comments"
  on public.mood_pin_comments for select
  using (true);

create policy "Authenticated users can add comments"
  on public.mood_pin_comments for insert
  with check (auth.uid() = user_id);

create policy "Users can delete own comments"
  on public.mood_pin_comments for delete
  using (auth.uid() = user_id);

-- ============================================================
-- 4. MOOD COMMENT NOTIFICATIONS
-- ============================================================
create table public.mood_comment_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  mood_pin_id uuid not null references public.mood_pins(id) on delete cascade,
  comment_id uuid not null references public.mood_pin_comments(id) on delete cascade,
  comment_text text not null,
  sentiment text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index idx_notifications_user on public.mood_comment_notifications(user_id, is_read);

alter table public.mood_comment_notifications enable row level security;

create policy "Users can read own notifications"
  on public.mood_comment_notifications for select
  using (auth.uid() = user_id);

create policy "Users can update own notifications"
  on public.mood_comment_notifications for update
  using (auth.uid() = user_id);

-- ============================================================
-- 5. VIDEO SESSIONS
-- ============================================================
create table public.video_sessions (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references auth.users(id) on delete cascade,
  host_name text not null,
  host_avatar_url text,
  title text not null,
  is_voice_only boolean not null default false,
  is_active boolean not null default true,
  participant_count int not null default 1,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '2 hours')
);

alter table public.video_sessions enable row level security;

create policy "Anyone can read active sessions"
  on public.video_sessions for select
  using (true);

create policy "Authenticated users can create sessions"
  on public.video_sessions for insert
  with check (auth.uid() = host_id);

create policy "Host can update own sessions"
  on public.video_sessions for update
  using (auth.uid() = host_id);

-- ============================================================
-- 6. SCHEDULED SESSIONS
-- ============================================================
create table public.scheduled_sessions (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references auth.users(id) on delete cascade,
  host_name text not null,
  host_avatar_url text,
  title text not null,
  description text,
  scheduled_time timestamptz not null,
  is_voice_only boolean not null default false,
  is_cancelled boolean not null default false,
  is_notified boolean not null default false,
  actual_session_id text,
  created_at timestamptz not null default now()
);

create index idx_scheduled_sessions_time on public.scheduled_sessions(scheduled_time);

alter table public.scheduled_sessions enable row level security;

create policy "Anyone can read scheduled sessions"
  on public.scheduled_sessions for select
  using (true);

create policy "Authenticated users can create scheduled sessions"
  on public.scheduled_sessions for insert
  with check (auth.uid() = host_id);

create policy "Host can update own scheduled sessions"
  on public.scheduled_sessions for update
  using (auth.uid() = host_id);

-- ============================================================
-- 7. STORIES
-- ============================================================
create table public.stories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  user_name text not null,
  user_avatar_url text,
  image_urls jsonb not null default '[]',
  view_count int not null default 0,
  viewed_by jsonb not null default '[]',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours')
);

alter table public.stories enable row level security;

create policy "Anyone can read active stories"
  on public.stories for select
  using (true);

create policy "Authenticated users can create stories"
  on public.stories for insert
  with check (auth.uid() = user_id);

create policy "Users can update own stories"
  on public.stories for update
  using (auth.uid() = user_id);

create policy "Users can delete own stories"
  on public.stories for delete
  using (auth.uid() = user_id);

-- ============================================================
-- 8. VIDEO POSTS (anonymous feed)
-- ============================================================
create table public.video_posts (
  id uuid primary key default gen_random_uuid(),
  video_url text not null,
  mood_tag text,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours')
);

alter table public.video_posts enable row level security;

create policy "Anyone can read video posts"
  on public.video_posts for select
  using (true);

create policy "Authenticated users can create video posts"
  on public.video_posts for insert
  with check (auth.role() = 'authenticated');

-- ============================================================
-- 9. USER MOOD PINS (tracks which user created which pin)
-- ============================================================
create table public.user_mood_pins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  mood_pin_id uuid not null references public.mood_pins(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.user_mood_pins enable row level security;

create policy "Users can read own mood pin links"
  on public.user_mood_pins for select
  using (auth.uid() = user_id);

create policy "Authenticated users can create mood pin links"
  on public.user_mood_pins for insert
  with check (auth.uid() = user_id);

-- ============================================================
-- HELPER RPC FUNCTIONS
-- ============================================================

-- Increment participant count when joining a session
create or replace function public.increment_participants(session_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  update public.video_sessions
  set participant_count = participant_count + 1
  where id = session_id and is_active = true;
end;
$$;

-- Decrement participant count when leaving a session
create or replace function public.decrement_participants(session_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  update public.video_sessions
  set participant_count = greatest(participant_count - 1, 0)
  where id = session_id;
end;
$$;

-- Increment story view count
create or replace function public.increment_view_count(story_id uuid, viewer_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  update public.stories
  set view_count = view_count + 1,
      viewed_by = viewed_by || to_jsonb(viewer_id::text)
  where id = story_id
    and not (viewed_by ? viewer_id::text);
end;
$$;

-- Auto-update updated_at timestamp
create or replace function public.handle_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger set_updated_at
  before update on public.log_entries
  for each row execute function public.handle_updated_at();

-- ============================================================
-- ENABLE REALTIME for mood_pins (used for live map)
-- ============================================================
alter publication supabase_realtime add table public.mood_pins;
alter publication supabase_realtime add table public.mood_pin_comments;
