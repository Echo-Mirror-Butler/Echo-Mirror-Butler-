create table future_letters (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  content text not null,
  created_at timestamptz default now(),
  unlock_at timestamptz not null
);

alter table future_letters enable row level security;

create policy "Users can read own letters" on future_letters
  for select using (auth.uid() = user_id);

create policy "Users can insert own letters" on future_letters
  for insert with check (auth.uid() = user_id);
