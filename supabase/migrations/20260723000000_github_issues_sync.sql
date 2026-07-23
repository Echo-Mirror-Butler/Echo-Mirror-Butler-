-- ============================================================
-- GitHub Issues Sync Table
-- For maintainer dashboard sync testing
-- ============================================================

create table public.github_issues (
  id uuid primary key default gen_random_uuid(),
  github_id bigint not null unique,
  github_number int not null,
  title text not null,
  body text,
  state text not null check (state in ('open', 'closed')),
  created_at timestamptz not null,
  updated_at timestamptz not null,
  user_login text not null,
  labels jsonb not null default '[]',
  sync_source text not null check (sync_source in ('cli', 'api', 'webhook')),
  synced_at timestamptz not null default now()
);

create index idx_github_issues_github_id on public.github_issues(github_id);
create index idx_github_issues_github_number on public.github_issues(github_number);
create index idx_github_issues_sync_source on public.github_issues(sync_source);
create index idx_github_issues_synced_at on public.github_issues(synced_at);

-- Enable RLS
alter table public.github_issues enable row level security;

-- Policy: Service role can read/write (for sync service)
create policy "Service role can manage github issues"
  on public.github_issues for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

-- Policy: Authenticated users can read (for maintainer dashboard)
create policy "Authenticated users can read github issues"
  on public.github_issues for select
  using (auth.role() = 'authenticated');
