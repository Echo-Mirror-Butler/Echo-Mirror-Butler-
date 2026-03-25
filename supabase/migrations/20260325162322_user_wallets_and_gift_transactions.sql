-- ============================================================
-- User Wallets & Gift Transactions
-- ============================================================

-- 1. USER WALLETS
-- Stores Stellar public keys and encrypted secrets for users.
drop table if exists public.echo_wallets cascade;
create table public.user_wallets (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references auth.users(id) on delete cascade,
  public_key        text not null,
  encrypted_secret  text not null,
  created_at        timestamptz not null default now()
);

-- 2. GIFT TRANSACTIONS
-- Log of ECHO transfers executed on the Stellar network.
drop table if exists public.gift_transactions cascade;
create table public.gift_transactions (
  id                  uuid primary key default gen_random_uuid(),
  sender_user_id      uuid references auth.users(id),
  recipient_user_id   uuid references auth.users(id),
  echo_amount         float8 not null,
  stellar_tx_hash     text,
  message             text,
  status              text not null default 'completed',
  created_at          timestamptz not null default now()
);

-- RLS
alter table public.user_wallets enable row level security;
alter table public.gift_transactions enable row level security;

-- user_wallets policies
create policy "Users can read their own wallet"
  on public.user_wallets for select
  using (auth.uid() = user_id);

-- gift_transactions policies
create policy "Users can read their own transactions"
  on public.gift_transactions for select
  using (auth.uid() = sender_user_id or auth.uid() = recipient_user_id);

create policy "Users can insert their own transactions"
  on public.gift_transactions for insert
  with check (auth.uid() = sender_user_id);
