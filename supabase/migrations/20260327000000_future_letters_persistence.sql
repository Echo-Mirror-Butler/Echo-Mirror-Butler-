create table if not exists public.future_letters (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  content text not null,
  created_at timestamptz default now(),
  unlock_at timestamptz not null
);

alter table public.future_letters enable row level security;

create index if not exists idx_future_letters_user_created_at
  on public.future_letters(user_id, created_at desc);

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'future_letters'
      and policyname = 'Users can read own letters'
  ) then
    create policy "Users can read own letters"
      on public.future_letters
      for select
      using (auth.uid() = user_id);
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'future_letters'
      and policyname = 'Users can insert own letters'
  ) then
    create policy "Users can insert own letters"
      on public.future_letters
      for insert
      with check (auth.uid() = user_id);
  end if;
end
$$;
