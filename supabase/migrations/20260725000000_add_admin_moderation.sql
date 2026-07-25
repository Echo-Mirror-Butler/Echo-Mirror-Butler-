-- Issue #586: admin/moderator role and moderation dashboard

-- Add role column to profiles table
alter table public.profiles
add column if not exists role text default 'user' check (role in ('user', 'admin', 'moderator'));

-- Create reported_content table
create table if not exists public.reported_content (
  id uuid primary key default gen_random_uuid(),
  content_type text not null check (content_type in ('mood_pin_comment')),
  content_id uuid not null,
  reported_by uuid not null references auth.users(id) on delete cascade,
  reason text not null,
  status text not null default 'pending' check (status in ('pending', 'reviewed', 'dismissed', 'action_taken')),
  admin_notes text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid references auth.users(id) on delete set null
);

create index if not exists idx_reported_content_status on public.reported_content(status);
create index if not exists idx_reported_content_created on public.reported_content(created_at desc);

alter table public.reported_content enable row level security;

create policy "Users can view reports" on public.reported_content
  for select using (auth.uid() = reported_by or
    exists (select 1 from public.profiles where id = auth.uid() and role in ('admin', 'moderator')));

create policy "Users can report content" on public.reported_content
  for insert with check (auth.uid() = reported_by);

create policy "Admins can update reports" on public.reported_content
  for update using (
    exists (select 1 from public.profiles where id = auth.uid() and role in ('admin', 'moderator'))
  ) with check (
    exists (select 1 from public.profiles where id = auth.uid() and role in ('admin', 'moderator'))
  );

-- Create audit_log table
create table if not exists public.audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references auth.users(id) on delete set null,
  action text not null,
  target_type text not null,
  target_id uuid,
  details jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_audit_log_created on public.audit_log(created_at desc);
create index if not exists idx_audit_log_actor on public.audit_log(actor_id);

alter table public.audit_log enable row level security;

create policy "Admins can view audit logs" on public.audit_log
  for select using (
    exists (select 1 from public.profiles where id = auth.uid() and role in ('admin', 'moderator'))
  );

-- Function to log admin actions
create or replace function public.log_audit_action(
  p_action text,
  p_target_type text,
  p_target_id uuid,
  p_details jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_log_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  insert into public.audit_log (actor_id, action, target_type, target_id, details)
  values (auth.uid(), p_action, p_target_type, p_target_id, p_details)
  returning id into v_log_id;

  return v_log_id;
end;
$$;

-- Function to update error_logs RLS for admin access
create policy "Admins can view all error logs" on public.error_logs
  for select using (
    exists (select 1 from public.profiles where id = auth.uid() and role in ('admin', 'moderator'))
  );
