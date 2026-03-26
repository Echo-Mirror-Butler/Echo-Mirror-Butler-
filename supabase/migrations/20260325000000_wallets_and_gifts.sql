-- ============================================================
-- Wallets and Gift Transactions
-- Supabase migration for local and production parity
-- ============================================================

-- ============================================================
-- 1. USER WALLETS
-- ============================================================
create table public.user_wallets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade unique,
  public_key text not null unique,
  encrypted_secret text not null,
  created_at timestamptz not null default now()
);

alter table public.user_wallets enable row level security;

create policy "Users can read own wallet"
  on public.user_wallets for select
  using (auth.uid() = user_id);

create policy "Users can insert own wallet"
  on public.user_wallets for insert
  with check (auth.uid() = user_id);

-- ============================================================
-- 2. GIFT TRANSACTIONS
-- ============================================================
create table public.gift_transactions (
  id uuid primary key default gen_random_uuid(),
  sender_user_id uuid references auth.users(id) on delete set null,
  recipient_user_id uuid references auth.users(id) on delete set null,
  echo_amount float8 not null check (echo_amount > 0),
  stellar_tx_hash text,
  message text,
  status text not null default 'completed' check (status in ('pending', 'completed', 'failed')),
  created_at timestamptz not null default now()
);

create index idx_gift_transactions_sender on public.gift_transactions(sender_user_id);
create index idx_gift_transactions_recipient on public.gift_transactions(recipient_user_id);

alter table public.gift_transactions enable row level security;

create policy "Users can read own transactions"
  on public.gift_transactions for select
  using (auth.uid() = sender_user_id or auth.uid() = recipient_user_id);

create policy "Authenticated users can insert transactions"
  on public.gift_transactions for insert
  with check (auth.uid() = sender_user_id);
