-- ============================================================
-- SQL Test: grant_echo_reward() Trigger & Wallet Updates
-- 
-- Run: psql $DATABASE_URL -f supabase/tests/test_echo_reward_trigger.sql
-- 
-- Safe to run on staging: wrapped in a ROLLBACK transaction.
-- ============================================================

BEGIN;

-- 1. Setup mock users
INSERT INTO auth.users (id, email)
VALUES 
  ('55555555-5555-5555-5555-555555555555'::uuid, 'user_reward@example.com'),
  ('66666666-6666-6666-6666-666666666666'::uuid, 'user_streak_bonus@example.com')
ON CONFLICT (id) DO NOTHING;

-- 2. Setup mock wallets (Ensure initial balance is 10.0)
-- Using valid 56-character Stellar public keys to satisfy CHECK constraints
INSERT INTO public.user_wallets (user_id, public_key, encrypted_secret, balance)
VALUES 
  ('55555555-5555-5555-5555-555555555555'::uuid, 'GG2C5LIUBGND3HYA56DM6V4IB67MCHM5UWO57E3BPO6ZMED3CQCCWHF2', 'secret5...', 10.0),
  ('66666666-6666-6666-6666-666666666666'::uuid, 'GH2C5LIUBGND3HYA56DM6V4IB67MCHM5UWO57E3BPO6ZMED3CQCCWHF2', 'secret6...', 10.0)
ON CONFLICT (user_id) DO NOTHING;


-- ── TEST 1: DAILY MOOD LOG REWARD ──
-- Insert first log today for User 5555...
INSERT INTO public.mood_logs (user_id, mood, country, city)
VALUES ('55555555-5555-5555-5555-555555555555'::uuid, '😊 happy', 'US', 'Austin');

-- Verify reward was logged
DO $$
DECLARE
  v_reward_amount int;
  v_reward_reason text;
  v_wallet_balance float8;
BEGIN
  -- Verify reward row exists
  SELECT amount, reason INTO v_reward_amount, v_reward_reason
  FROM public.echo_rewards
  WHERE user_id = '55555555-5555-5555-5555-555555555555'::uuid;
  
  -- Verify wallet balance updated
  SELECT balance INTO v_wallet_balance
  FROM public.user_wallets
  WHERE user_id = '55555555-5555-5555-5555-555555555555'::uuid;

  IF v_reward_amount = 1 AND v_reward_reason = 'daily_mood_log' AND v_wallet_balance = 11.0 THEN
    RAISE NOTICE 'SUCCESS: Daily reward granted correctly. Reason: %, Amount: %, Wallet Balance: %', 
      v_reward_reason, v_reward_amount, v_wallet_balance;
  ELSE
    RAISE EXCEPTION 'FAIL: Daily reward failed. Reason: %, Amount: %, Wallet Balance: %', 
      v_reward_reason, v_reward_amount, v_wallet_balance;
  END IF;
END;
$$;


-- ── TEST 2: FARMING PREVENTION ──
-- Insert a second log today for User 5555...
INSERT INTO public.mood_logs (user_id, mood, country, city)
VALUES ('55555555-5555-5555-5555-555555555555'::uuid, '😴 tired', 'US', 'Austin');

-- Verify NO extra rewards or balance increases were recorded
DO $$
DECLARE
  v_reward_count int;
  v_wallet_balance float8;
BEGIN
  SELECT count(*) INTO v_reward_count
  FROM public.echo_rewards
  WHERE user_id = '55555555-5555-5555-5555-555555555555'::uuid;
  
  SELECT balance INTO v_wallet_balance
  FROM public.user_wallets
  WHERE user_id = '55555555-5555-5555-5555-555555555555'::uuid;

  IF v_reward_count = 1 AND v_wallet_balance = 11.0 THEN
    RAISE NOTICE 'SUCCESS: Farming prevention block active. Reward rows: %, Wallet Balance: %', 
      v_reward_count, v_wallet_balance;
  ELSE
    RAISE EXCEPTION 'FAIL: Farming prevention failed. Reward rows: %, Wallet Balance: %', 
      v_reward_count, v_wallet_balance;
  END IF;
END;
$$;


-- ── TEST 3: 7-DAY STREAK BONUS ──
-- Disable trigger during historical insert to avoid daily farming caps
ALTER TABLE public.mood_logs DISABLE TRIGGER on_mood_log_insert_reward;

-- Insert logs for the past 6 consecutive days (Days 1 to 6)
INSERT INTO public.mood_logs (user_id, mood, created_at)
VALUES 
  ('66666666-6666-6666-6666-666666666666'::uuid, '😊 happy', NOW() - INTERVAL '1 day'),
  ('66666666-6666-6666-6666-666666666666'::uuid, '😊 happy', NOW() - INTERVAL '2 day'),
  ('66666666-6666-6666-6666-666666666666'::uuid, '😊 happy', NOW() - INTERVAL '3 day'),
  ('66666666-6666-6666-6666-666666666666'::uuid, '😊 happy', NOW() - INTERVAL '4 day'),
  ('66666666-6666-6666-6666-666666666666'::uuid, '😊 happy', NOW() - INTERVAL '5 day'),
  ('66666666-6666-6666-6666-666666666666'::uuid, '😊 happy', NOW() - INTERVAL '6 day');

-- Re-enable trigger
ALTER TABLE public.mood_logs ENABLE TRIGGER on_mood_log_insert_reward;

-- Insert the 7th log today to complete the 7-day streak
INSERT INTO public.mood_logs (user_id, mood, country, city)
VALUES ('66666666-6666-6666-6666-666666666666'::uuid, '😎 awesome', 'US', 'Austin');

-- Verify that a 5 token bonus with reason '7_day_streak_bonus' was rewarded
-- 
-- NOTE ON DESIGN INTENT: According to the grant_echo_reward() trigger implementation,
-- when a 7-day streak is reached, the 5 ECHO streak bonus REPLACES the 1 ECHO daily reward.
-- It does not stack (+5 instead of +6). Thus, the expected wallet balance increases by
-- 5.0 (10.0 initial + 5.0 bonus = 15.0). This is the intended behavior of the migration script.
DO $$
DECLARE
  v_reward_amount int;
  v_reward_reason text;
  v_wallet_balance float8;
BEGIN
  -- Verify reward row details
  SELECT amount, reason INTO v_reward_amount, v_reward_reason
  FROM public.echo_rewards
  WHERE user_id = '66666666-6666-6666-6666-666666666666'::uuid;
  
  -- Verify wallet balance updated by +5 (10.0 + 5 = 15.0)
  SELECT balance INTO v_wallet_balance
  FROM public.user_wallets
  WHERE user_id = '66666666-6666-6666-6666-666666666666'::uuid;

  IF v_reward_amount = 5 AND v_reward_reason = '7_day_streak_bonus' AND v_wallet_balance = 15.0 THEN
    RAISE NOTICE 'SUCCESS: 7-day streak bonus granted correctly. Reason: %, Amount: %, Wallet Balance: %', 
      v_reward_reason, v_reward_amount, v_wallet_balance;
  ELSE
    RAISE EXCEPTION 'FAIL: 7-day streak bonus failed. Reason: %, Amount: %, Wallet Balance: %', 
      v_reward_reason, v_reward_amount, v_wallet_balance;
  END IF;
END;
$$;

-- Rollback mock data
ROLLBACK;
