-- ============================================================
-- Issue #652: maintenance-mode banner remote-config flag
-- ============================================================

create table if not exists public.app_maintenance (
  id int primary key default 1,
  enabled boolean not null default false,
  message text,
  expected_end_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint app_maintenance_singleton check (id = 1)
);

-- Seed the single config row if it doesn't exist yet.
insert into public.app_maintenance (id, enabled)
values (1, false)
on conflict (id) do nothing;

alter table public.app_maintenance enable row level security;

-- Readable by anyone (including signed-out visitors) so the banner
-- can show before login. Toggling `enabled`/`message`/`expected_end_at`
-- is done via the Supabase dashboard (service role bypasses RLS) —
-- no insert/update/delete policy is granted to regular users.
do $$
begin
  create policy "Anyone can read maintenance status"
    on public.app_maintenance for select
    using (true);
exception
  when duplicate_object then null;
end $$;
