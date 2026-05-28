-- ============================================================
-- SQL Test: calculate_streak(user_id) RPC calculations
-- 
-- Run: psql $DATABASE_URL -f supabase/tests/test_streak_rpc.sql
-- 
-- Safe to run on staging: wrapped in a ROLLBACK transaction.
-- ============================================================

BEGIN;

-- 1. Setup mock users
INSERT INTO auth.users (id, email)
VALUES 
  ('11111111-1111-1111-1111-111111111111'::uuid, 'user_zero@example.com'),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'user_single@example.com'),
  ('33333333-3333-3333-3333-333333333333'::uuid, 'user_multi@example.com'),
  ('44444444-4444-4444-4444-444444444444'::uuid, 'user_broken@example.com')
ON CONFLICT (id) DO NOTHING;

-- 2. Setup mock wallets (required because reward trigger fires on insert)
-- Using valid 56-character Stellar public keys to satisfy CHECK constraints
INSERT INTO public.user_wallets (user_id, public_key, encrypted_secret, balance)
VALUES 
  ('11111111-1111-1111-1111-111111111111'::uuid, 'GC2C5LIUBGND3HYA56DM6V4IB67MCHM5UWO57E3BPO6ZMED3CQCCWHF2', 'secret...', 10.0),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'GD2C5LIUBGND3HYA56DM6V4IB67MCHM5UWO57E3BPO6ZMED3CQCCWHF2', 'secret...', 10.0),
  ('33333333-3333-3333-3333-333333333333'::uuid, 'GE2C5LIUBGND3HYA56DM6V4IB67MCHM5UWO57E3BPO6ZMED3CQCCWHF2', 'secret...', 10.0),
  ('44444444-4444-4444-4444-444444444444'::uuid, 'GF2C5LIUBGND3HYA56DM6V4IB67MCHM5UWO57E3BPO6ZMED3CQCCWHF2', 'secret...', 10.0)
ON CONFLICT (user_id) DO NOTHING;

-- Disable trigger on mood_logs during inserting historical logs to prevent daily reward limits
-- (Because farming prevention limits rewards to 1 per day, which would interfere if we insert multiple logs for today, etc.)
ALTER TABLE public.mood_logs DISABLE TRIGGER on_mood_log_insert_reward;


-- ── TEST 1: ZERO STREAK ──
-- No logs inserted for user 1111...
DO $$
DECLARE
  v_res json;
BEGIN
  v_res := calculate_streak('11111111-1111-1111-1111-111111111111'::uuid);
  
  IF (v_res->>'current_streak')::int = 0 AND (v_res->>'longest_streak')::int = 0 AND (v_res->>'last_log_date') IS NULL THEN
    RAISE NOTICE 'SUCCESS: Zero streak test passed. Result: %', v_res;
  ELSE
    RAISE EXCEPTION 'FAIL: Zero streak returned unexpected values: %', v_res;
  END IF;
END;
$$;


-- ── TEST 2: SINGLE-DAY STREAK ──
-- Log today for user 2222...
INSERT INTO public.mood_logs (user_id, mood, created_at)
VALUES ('22222222-2222-2222-2222-222222222222'::uuid, '😊 happy', NOW());

DO $$
DECLARE
  v_res json;
BEGIN
  v_res := calculate_streak('22222222-2222-2222-2222-222222222222'::uuid);
  
  IF (v_res->>'current_streak')::int = 1 AND (v_res->>'longest_streak')::int = 1 AND (v_res->>'last_log_date')::date = CURRENT_DATE THEN
    RAISE NOTICE 'SUCCESS: Single-day streak test passed. Result: %', v_res;
  ELSE
    RAISE EXCEPTION 'FAIL: Single-day streak returned unexpected values: %', v_res;
  END IF;
END;
$$;


-- ── TEST 3: MULTI-DAY STREAK ──
-- Logs for today, yesterday, and 2 days ago for user 3333...
INSERT INTO public.mood_logs (user_id, mood, created_at)
VALUES 
  ('33333333-3333-3333-3333-333333333333'::uuid, '😊 happy', NOW()),
  ('33333333-3333-3333-3333-333333333333'::uuid, '😊 happy', NOW() - INTERVAL '1 day'),
  ('33333333-3333-3333-3333-333333333333'::uuid, '😊 happy', NOW() - INTERVAL '2 day');

DO $$
DECLARE
  v_res json;
BEGIN
  v_res := calculate_streak('33333333-3333-3333-3333-333333333333'::uuid);
  
  IF (v_res->>'current_streak')::int = 3 AND (v_res->>'longest_streak')::int = 3 THEN
    RAISE NOTICE 'SUCCESS: Multi-day streak test passed. Result: %', v_res;
  ELSE
    RAISE EXCEPTION 'FAIL: Multi-day streak returned unexpected values: %', v_res;
  END IF;
END;
$$;


-- ── TEST 4: BROKEN STREAK ──
-- Active streak of 2 (today, yesterday)
-- Gap of 2 days (no logs for CURRENT_DATE - 2, CURRENT_DATE - 3)
-- Inactive historical streak of 4 (consecutive 4 days before that)
INSERT INTO public.mood_logs (user_id, mood, created_at)
VALUES 
  -- Active streak (2 days)
  ('44444444-4444-4444-4444-444444444444'::uuid, '😊 happy', NOW()),
  ('44444444-4444-4444-4444-444444444444'::uuid, '😊 happy', NOW() - INTERVAL '1 day'),
  -- Gap of 2 days
  -- Historical longest streak of 4 days
  ('44444444-4444-4444-4444-444444444444'::uuid, '😊 happy', NOW() - INTERVAL '4 day'),
  ('44444444-4444-4444-4444-444444444444'::uuid, '😊 happy', NOW() - INTERVAL '5 day'),
  ('44444444-4444-4444-4444-444444444444'::uuid, '😊 happy', NOW() - INTERVAL '6 day'),
  ('44444444-4444-4444-4444-444444444444'::uuid, '😊 happy', NOW() - INTERVAL '7 day');

DO $$
DECLARE
  v_res json;
BEGIN
  v_res := calculate_streak('44444444-4444-4444-4444-444444444444'::uuid);
  
  IF (v_res->>'current_streak')::int = 2 AND (v_res->>'longest_streak')::int = 4 THEN
    RAISE NOTICE 'SUCCESS: Broken/Longest streak test passed. Result: %', v_res;
  ELSE
    RAISE EXCEPTION 'FAIL: Broken/Longest streak returned unexpected values: %', v_res;
  END IF;
END;
$$;


-- Re-enable triggers to leave table in clean original state
ALTER TABLE public.mood_logs ENABLE TRIGGER on_mood_log_insert_reward;

-- Rollback mock data
ROLLBACK;
