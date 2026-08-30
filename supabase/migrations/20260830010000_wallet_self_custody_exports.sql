create table if not exists public.wallet_export_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  public_key text,
  outcome text not null check (outcome in ('SUCCEEDED', 'DENIED', 'FAILED')),
  reason text,
  mfa_verified boolean not null default false,
  self_custody_verified_at timestamptz,
  custodial_management_disabled_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists wallet_export_events_user_created_idx
  on public.wallet_export_events (user_id, created_at desc);

alter table public.wallet_export_events enable row level security;

-- Export audit events are intentionally service-role only. Users must not be
-- able to erase or forge evidence of this high-risk account action.
revoke all on public.wallet_export_events from anon, authenticated;
