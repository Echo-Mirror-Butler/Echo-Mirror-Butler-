-- ============================================================
-- Stellar wallet and gift transaction tables
-- Required by the Node.js Stellar API server (issue #103)
-- ============================================================

-- ── 1. USER WALLETS ────────────────────────────────────────
-- Stores each user's Stellar testnet public key.
-- The secret key is stored server-side and never exposed to clients.
create table public.user_wallets (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  public_key  text not null,
  secret_key  text not null,
  created_at  timestamptz not null default now(),
  constraint user_wallets_user_id_unique unique (user_id),
  constraint user_wallets_public_key_unique unique (public_key)
);

alter table public.user_wallets enable row level security;

-- Users can read only their own wallet public key (never the secret key).
-- The server accesses this table via the service role key (bypasses RLS).
create policy "Users can read own wallet"
  on public.user_wallets for select
  using (auth.uid() = user_id);

-- ── 2. GIFT TRANSACTIONS ───────────────────────────────────
create table public.gift_transactions (
  id            uuid primary key default gen_random_uuid(),
  sender_id     uuid not null references auth.users(id) on delete cascade,
  recipient_id  uuid not null references auth.users(id) on delete cascade,
  amount        numeric(18, 7) not null check (amount > 0),
  tx_hash       text,
  status        text not null default 'pending'
                  check (status in ('pending', 'completed', 'failed')),
  message       text,
  created_at    timestamptz not null default now()
);

create index idx_gift_transactions_sender   on public.gift_transactions(sender_id, created_at desc);
create index idx_gift_transactions_recipient on public.gift_transactions(recipient_id, created_at desc);

alter table public.gift_transactions enable row level security;

create policy "Users can read own gift transactions"
  on public.gift_transactions for select
  using (auth.uid() = sender_id or auth.uid() = recipient_id);
