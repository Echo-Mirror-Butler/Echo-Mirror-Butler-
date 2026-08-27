-- ============================================================
-- SQL Test: enforce_mood_log_rate_limit() Trigger on log_entries
--
-- Run: psql $DATABASE_URL -f supabase/manual_tests/test_mood_log_rate_limit.sql
--
-- Safe to run on staging: wrapped in a ROLLBACK transaction.
-- ============================================================

BEGIN;

-- 1. Setup mock user
INSERT INTO auth.users (id, email)
VALUES ('77777777-7777-7777-7777-777777777777'::uuid, 'user_rate_limit@example.com')
ON CONFLICT (id) DO NOTHING;

-- 2. Insert 10 log entries — should all succeed (at the limit, not over it)
DO $$
DECLARE
  i int;
BEGIN
  FOR i IN 1..10 LOOP
    INSERT INTO public.log_entries (user_id, date, mood)
    VALUES ('77777777-7777-7777-7777-777777777777'::uuid, now()::date, 3);
  END LOOP;
END;
$$;

DO $$
DECLARE
  v_count int;
BEGIN
  SELECT count(*) INTO v_count
  FROM public.log_entries
  WHERE user_id = '77777777-7777-7777-7777-777777777777'::uuid;

  IF v_count = 10 THEN
    RAISE NOTICE 'SUCCESS: 10 log entries created within limit. Count: %', v_count;
  ELSE
    RAISE EXCEPTION 'FAIL: Expected 10 log entries, got %', v_count;
  END IF;
END;
$$;

-- 3. The 11th insert within the same rolling hour must be rejected with PT429 (HTTP 429)
DO $$
BEGIN
  BEGIN
    INSERT INTO public.log_entries (user_id, date, mood)
    VALUES ('77777777-7777-7777-7777-777777777777'::uuid, now()::date, 4);

    RAISE EXCEPTION 'FAIL: 11th log entry should have been rate-limited but was inserted';
  EXCEPTION
    WHEN sqlstate 'PT429' THEN
      RAISE NOTICE 'SUCCESS: 11th log entry correctly rate-limited: %', sqlerrm;
  END;
END;
$$;

-- Verify still only 10 rows persisted (the rejected insert did not land)
DO $$
DECLARE
  v_count int;
BEGIN
  SELECT count(*) INTO v_count
  FROM public.log_entries
  WHERE user_id = '77777777-7777-7777-7777-777777777777'::uuid;

  IF v_count = 10 THEN
    RAISE NOTICE 'SUCCESS: rate-limited insert did not persist. Count: %', v_count;
  ELSE
    RAISE EXCEPTION 'FAIL: Expected 10 log entries after rejection, got %', v_count;
  END IF;
END;
$$;

-- Rollback mock data
ROLLBACK;
