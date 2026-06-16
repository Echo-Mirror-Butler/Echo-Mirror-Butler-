-- ============================================================
-- Mood Comment Notifications
-- ============================================================

create table public.mood_comment_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  mood_pin_id uuid not null,
  comment_id uuid not null,
  comment_text text,
  sentiment text default 'neutral',
  is_read boolean default false,
  created_at timestamptz not null default now()
);

create index idx_mood_comment_notifications_user on public.mood_comment_notifications(user_id);

alter table public.mood_comment_notifications enable row level security;

create policy "Users can read own notifications"
  on public.mood_comment_notifications for select
  using (auth.uid() = user_id);

create policy "Users can insert own notifications"
  on public.mood_comment_notifications for insert
  with check (auth.uid() = user_id);

create policy "Users can update own notifications"
  on public.mood_comment_notifications for update
  using (auth.uid() = user_id);

create policy "Users can delete own notifications"
  on public.mood_comment_notifications for delete
  using (auth.uid() = user_id);
