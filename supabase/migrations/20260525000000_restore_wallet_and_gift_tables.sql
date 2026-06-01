-- Restore canonical wallet and gift transaction tables for local migrations.
-- Later migrations add wallet balance columns and ECHO reward behavior.

create table if not exists public.user_wallets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade unique,
  public_key text unique,
  encrypted_secret text,
  created_at timestamptz not null default now()
);

alter table public.user_wallets
  add column if not exists id uuid default gen_random_uuid(),
  add column if not exists user_id uuid,
  add column if not exists public_key text,
  add column if not exists encrypted_secret text,
  add column if not exists created_at timestamptz not null default now();

alter table public.user_wallets
  alter column id set default gen_random_uuid(),
  alter column created_at set default now();

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'user_wallets_user_id_fkey'
      and conrelid = 'public.user_wallets'::regclass
  ) then
    alter table public.user_wallets
      add constraint user_wallets_user_id_fkey
      foreign key (user_id) references auth.users(id) on delete cascade;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'user_wallets_user_id_key'
      and conrelid = 'public.user_wallets'::regclass
  ) then
    alter table public.user_wallets
      add constraint user_wallets_user_id_key unique (user_id);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'user_wallets_public_key_key'
      and conrelid = 'public.user_wallets'::regclass
  ) then
    alter table public.user_wallets
      add constraint user_wallets_public_key_key unique (public_key);
  end if;
end $$;

alter table public.user_wallets enable row level security;

do $$
begin
  create policy "Users can read own wallet"
    on public.user_wallets for select
    using (auth.uid() = user_id);
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create policy "Users can insert own wallet"
    on public.user_wallets for insert
    with check (auth.uid() = user_id);
exception
  when duplicate_object then null;
end $$;

create table if not exists public.gift_transactions (
  id uuid primary key default gen_random_uuid(),
  sender_user_id uuid references auth.users(id) on delete set null,
  recipient_user_id uuid references auth.users(id) on delete set null,
  echo_amount float8 not null check (echo_amount > 0),
  stellar_tx_hash text,
  message text,
  status text not null default 'completed' check (status in ('pending', 'completed', 'failed')),
  created_at timestamptz not null default now()
);

alter table public.gift_transactions
  add column if not exists id uuid default gen_random_uuid(),
  add column if not exists sender_user_id uuid,
  add column if not exists recipient_user_id uuid,
  add column if not exists echo_amount float8,
  add column if not exists stellar_tx_hash text,
  add column if not exists message text,
  add column if not exists status text not null default 'completed',
  add column if not exists created_at timestamptz not null default now();

alter table public.gift_transactions
  alter column id set default gen_random_uuid(),
  alter column status set default 'completed',
  alter column created_at set default now();

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'gift_transactions_sender_user_id_fkey'
      and conrelid = 'public.gift_transactions'::regclass
  ) then
    alter table public.gift_transactions
      add constraint gift_transactions_sender_user_id_fkey
      foreign key (sender_user_id) references auth.users(id) on delete set null;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'gift_transactions_recipient_user_id_fkey'
      and conrelid = 'public.gift_transactions'::regclass
  ) then
    alter table public.gift_transactions
      add constraint gift_transactions_recipient_user_id_fkey
      foreign key (recipient_user_id) references auth.users(id) on delete set null;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'gift_transactions_echo_amount_check'
      and conrelid = 'public.gift_transactions'::regclass
  ) then
    alter table public.gift_transactions
      add constraint gift_transactions_echo_amount_check check (echo_amount > 0);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'gift_transactions_status_check'
      and conrelid = 'public.gift_transactions'::regclass
  ) then
    alter table public.gift_transactions
      add constraint gift_transactions_status_check check (status in ('pending', 'completed', 'failed'));
  end if;
end $$;

create index if not exists idx_gift_transactions_sender
  on public.gift_transactions(sender_user_id);

create index if not exists idx_gift_transactions_recipient
  on public.gift_transactions(recipient_user_id);

alter table public.gift_transactions enable row level security;

do $$
begin
  create policy "Users can read own transactions"
    on public.gift_transactions for select
    using (auth.uid() = sender_user_id or auth.uid() = recipient_user_id);
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create policy "Authenticated users can insert transactions"
    on public.gift_transactions for insert
    with check (auth.uid() = sender_user_id);
exception
  when duplicate_object then null;
end $$;
