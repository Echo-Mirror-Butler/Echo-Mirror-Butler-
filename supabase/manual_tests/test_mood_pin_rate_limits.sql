-- ============================================================
-- SQL Test: enforce_mood_pin_comment_rate_limit() and
--           enforce_mood_pin_drop_rate_limit() Triggers
--
-- Issue #588
--
-- Run: psql $DATABASE_URL -f supabase/manual_tests/test_mood_pin_rate_limits.sql
--
-- Safe to run on staging: wrapped in a ROLLBACK transaction.
-- ============================================================

BEGIN;

-- ── Setup ─────────────────────────────────────────────────────────────────────

INSERT INTO auth.users (id, email)
VALUES ('88888888-8888-8888-8888-888888888888'::uuid, 'user_pin_rate_limit@example.com')
ON CONFLICT (id) DO NOTHING;

-- ── Test 1: Mood pin comment rate limit (20/hour) ─────────────────────────────

-- Insert a mood pin first (so we have something to comment on)
INSERT INTO public.mood_pins (id, sentiment, grid_lat, grid_lon)
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, 'happy', 40.0, -74.0);

INSERT INTO public.user_mood_pins (user_id, mood_pin_id)
VALUES ('88888888-8888-8888-8888-888888888888'::uuid, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid);

-- Insert 20 comments — should all succeed (at the limit)
DO $$
DECLARE
  i int;
BEGIN
  FOR i IN 1..20 LOOP
    INSERT INTO public.mood_pin_comments (mood_pin_id, user_id, text)
    VALUES (
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
      '88888888-8888-8888-8888-888888888888'::uuid,
      'Comment ' || i
    );
  END LOOP;
END;
$$;

DO $$
DECLARE
  v_count int;
BEGIN
  SELECT count(*) INTO v_count
  FROM public.mood_pin_comments
  WHERE user_id = '88888888-8888-8888-8888-888888888888'::uuid;

  IF v_count = 20 THEN
    RAISE NOTICE 'SUCCESS: 20 comments created within limit. Count: %', v_count;
  ELSE
    RAISE EXCEPTION 'FAIL: Expected 20 comments, got %', v_count;
  END IF;
END;
$$;

-- The 21st comment must be rate-limited with PT429
DO $$
BEGIN
  BEGIN
    INSERT INTO public.mood_pin_comments (mood_pin_id, user_id, text)
    VALUES (
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
      '88888888-8888-8888-8888-888888888888'::uuid,
      'Comment 21 — should be rejected'
    );

    RAISE EXCEPTION 'FAIL: 21st comment should have been rate-limited but was inserted';
  EXCEPTION
    WHEN sqlstate 'PT429' THEN
      RAISE NOTICE 'SUCCESS: 21st comment correctly rate-limited: %', sqlerrm;
  END;
END;
$$;

-- Verify still only 20 rows persisted
DO $$
DECLARE
  v_count int;
BEGIN
  SELECT count(*) INTO v_count
  FROM public.mood_pin_comments
  WHERE user_id = '88888888-8888-8888-8888-888888888888'::uuid;

  IF v_count = 20 THEN
    RAISE NOTICE 'SUCCESS: rate-limited comment did not persist. Count: %', v_count;
  ELSE
    RAISE EXCEPTION 'FAIL: Expected 20 comments after rejection, got %', v_count;
  END IF;
END;
$$;

-- ── Test 2: Mood pin drop rate limit (10/hour) ────────────────────────────────

-- Insert 10 more pins for this user — should succeed (at the limit)
DO $$
DECLARE
  i int;
  v_pin_id uuid;
BEGIN
  FOR i IN 1..10 LOOP
    v_pin_id := gen_random_uuid();
    INSERT INTO public.mood_pins (id, sentiment, grid_lat, grid_lon)
    VALUES (v_pin_id, 'calm', 40.0 + i, -74.0 + i);
    INSERT INTO public.user_mood_pins (user_id, mood_pin_id)
    VALUES ('88888888-8888-8888-8888-888888888888'::uuid, v_pin_id);
  END LOOP;
END;
$$;

DO $$
DECLARE
  v_count int;
BEGIN
  SELECT count(*) INTO v_count
  FROM public.user_mood_pins
  WHERE user_id = '88888888-8888-8888-8888-888888888888'::uuid;

  IF v_count = 11 THEN
    RAISE NOTICE 'SUCCESS: 11 pins created (1 initial + 10 drops). Count: %', v_count;
  ELSE
    RAISE EXCEPTION 'FAIL: Expected 11 pins, got %', v_count;
  END IF;
END;
$$;

-- The 11th pin drop (12th total for this user) must be rate-limited
DO $$
DECLARE
  v_pin_id uuid;
BEGIN
  v_pin_id := gen_random_uuid();
  BEGIN
    INSERT INTO public.mood_pins (id, sentiment, grid_lat, grid_lon)
    VALUES (v_pin_id, 'sad', 50.0, -64.0);
    INSERT INTO public.user_mood_pins (user_id, mood_pin_id)
    VALUES ('88888888-8888-8888-8888-888888888888'::uuid, v_pin_id);

    RAISE EXCEPTION 'FAIL: 11th pin drop should have been rate-limited but was inserted';
  EXCEPTION
    WHEN sqlstate 'PT429' THEN
      RAISE NOTICE 'SUCCESS: 11th pin drop correctly rate-limited: %', sqlerrm;
  END;
END;
$$;

-- Rollback all test data
ROLLBACK;
