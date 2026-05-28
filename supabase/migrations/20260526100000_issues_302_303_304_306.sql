-- ============================================================
-- Issues #302, #303, #304, #306
-- ============================================================

-- ============================================================
-- Issue #304: profiles table for avatar, display name, timezone
-- ============================================================
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  timezone text default 'UTC',
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Users can read own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can insert own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 2097152, array['image/png', 'image/jpeg'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "Avatar images are publicly readable"
  on storage.objects for select
  using (bucket_id = 'avatars');

create policy "Users can upload own avatar"
  on storage.objects for insert
  with check (bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]);

create policy "Users can update own avatar"
  on storage.objects for update
  using (bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1])
  with check (bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]);

-- Auto-create profile on user signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into public.profiles (id)
  values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.delete_user()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  delete from auth.users where id = auth.uid();
end;
$$;

-- ============================================================
-- Issue #302: structured AI insight fields
-- ============================================================
alter table public.ai_insights
add column if not exists mood_drivers jsonb default '[]',
add column if not exists best_time_of_day text,
add column if not exists worst_time_of_day text,
add column if not exists recommendations jsonb default '[]';

-- ============================================================
-- Issue #303: push_subscriptions table for Web Push
-- ============================================================
create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  reminder_enabled boolean not null default true,
  reminder_time text not null default '09:00',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_push_subscriptions_user on public.push_subscriptions(user_id);

alter table public.push_subscriptions enable row level security;

create policy "Users can read own push subscriptions"
  on public.push_subscriptions for select
  using (auth.uid() = user_id);

create policy "Users can insert own push subscriptions"
  on public.push_subscriptions for insert
  with check (auth.uid() = user_id);

create policy "Users can update own push subscriptions"
  on public.push_subscriptions for update
  using (auth.uid() = user_id);

create policy "Users can delete own push subscriptions"
  on public.push_subscriptions for delete
  using (auth.uid() = user_id);

-- ============================================================
-- Issue #306: mood_logs table for Global Mirror realtime ticker
-- (mood_pins already exists; mood_logs is for country-level aggregation)
-- ============================================================
create table if not exists public.mood_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  country text,
  city text,
  mood text not null,
  created_at timestamptz not null default now()
);

create index idx_mood_logs_created on public.mood_logs(created_at desc);
create index idx_mood_logs_country on public.mood_logs(country);

alter table public.mood_logs enable row level security;

create policy "Anyone can read mood logs"
  on public.mood_logs for select
  using (true);

create policy "Authenticated users can insert mood logs"
  on public.mood_logs for insert
  with check (auth.role() = 'authenticated');

-- Enable realtime for mood_logs
alter publication supabase_realtime add table public.mood_logs;

-- Enable realtime for profiles
alter publication supabase_realtime add table public.profiles;
