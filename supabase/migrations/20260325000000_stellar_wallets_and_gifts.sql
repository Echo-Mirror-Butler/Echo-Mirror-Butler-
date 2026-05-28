-- Obsolete compatibility migration.
-- The active Supabase schema for wallets and gifts lives in later migrations
-- that create public.user_wallets with encrypted_secret and
-- public.gift_transactions with sender_user_id / recipient_user_id.
select 1;
