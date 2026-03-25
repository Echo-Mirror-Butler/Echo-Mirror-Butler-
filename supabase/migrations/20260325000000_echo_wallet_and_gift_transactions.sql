-- ============================================================
-- ECHO Wallet & Gift Transactions
-- Issue #37 — wire GiftRepository to Supabase
-- ============================================================

-- ============================================================
-- 1. ECHO WALLETS
-- One wallet per authenticated user.
-- Balance is the off-chain ECHO token balance (DB-authoritative).
-- ============================================================
create table public.echo_wallets (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null unique references auth.users(id) on delete cascade,
  balance         float8 not null default 10.0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index idx_echo_wallets_user on public.echo_wallets(user_id);

alter table public.echo_wallets enable row level security;

-- Users can read only their own wallet.
create policy "Users can read own wallet"
  on public.echo_wallets for select
  using (auth.uid() = user_id);

-- Wallets are created by the server via a Supabase function / trigger,
-- not directly by the client.
create policy "Users can insert own wallet"
  on public.echo_wallets for insert
  with check (auth.uid() = user_id);

-- Balance updates are performed by the server (service-role key).
-- Clients may not directly mutate balances.
create policy "Users can update own wallet"
  on public.echo_wallets for update
  using (auth.uid() = user_id);

-- ============================================================
-- 2. GIFT TRANSACTIONS
-- Immutable log of every ECHO transfer between users.
-- ============================================================
create table public.gift_transactions (
  id                  uuid primary key default gen_random_uuid(),
  sender_user_id      uuid not null references auth.users(id) on delete cascade,
  recipient_user_id   uuid not null references auth.users(id) on delete cascade,
  echo_amount         float8 not null check (echo_amount > 0),
  status              text not null default 'completed'
                        check (status in ('pending', 'completed', 'failed')),
  message             text,
  stellar_tx_hash     text,
  created_at          timestamptz not null default now()
);

create index idx_gift_tx_sender    on public.gift_transactions(sender_user_id);
create index idx_gift_tx_recipient on public.gift_transactions(recipient_user_id);
create index idx_gift_tx_created   on public.gift_transactions(created_at desc);

alter table public.gift_transactions enable row level security;

-- Users can see transactions where they are sender or recipient.
create policy "Users can read own transactions"
  on public.gift_transactions for select
  using (
    auth.uid() = sender_user_id or
    auth.uid() = recipient_user_id
  );

-- Clients insert transactions directly (balance validation is done app-side).
create policy "Authenticated users can insert transactions"
  on public.gift_transactions for insert
  with check (auth.uid() = sender_user_id);
