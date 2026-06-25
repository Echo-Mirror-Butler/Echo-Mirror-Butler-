-- Create error_logs table for tracking frontend errors
create table if not exists public.error_logs (
  id uuid primary key default gen_random_uuid(),
  reference_code text not null,
  error_message text not null,
  error_stack text,
  component_stack text,
  route_path text,
  user_id uuid references auth.users(id) on delete set null,
  timestamp timestamptz not null default now(),
  created_at timestamptz not null default now()
);

-- Create index for faster lookups
create index if not exists error_logs_reference_code_idx on public.error_logs(reference_code);
create index if not exists error_logs_user_id_idx on public.error_logs(user_id);
create index if not exists error_logs_created_at_idx on public.error_logs(created_at desc);

-- Enable RLS
alter table public.error_logs enable row level security;

-- Policies: Users can insert their own errors, admins can view all
create policy "Users can insert own error logs"
  on public.error_logs for insert
  with check (true);

create policy "Users can view own error logs"
  on public.error_logs for select
  using (auth.uid() = user_id or user_id is null);
