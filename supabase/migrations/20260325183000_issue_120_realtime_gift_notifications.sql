-- Issue #120: Enable realtime gift notifications for live sessions.

alter table if exists public.gift_transactions enable row level security;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public' and table_name = 'gift_transactions'
  ) and not exists (
    select 1
    from pg_publication_rel pr
    join pg_publication p on p.oid = pr.prpubid
    join pg_class c on c.oid = pr.prrelid
    join pg_namespace n on n.oid = c.relnamespace
    where p.pubname = 'supabase_realtime'
      and n.nspname = 'public'
      and c.relname = 'gift_transactions'
  ) then
    alter publication supabase_realtime add table public.gift_transactions;
  end if;
end $$;

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public' and table_name = 'gift_transactions'
  ) and not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'gift_transactions'
      and policyname = 'Recipients can receive realtime gift events'
  ) then
    create policy "Recipients can receive realtime gift events"
      on public.gift_transactions
      for select
      using (auth.uid()::text = recipient_user_id::text);
  end if;
end $$;
