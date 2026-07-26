-- ============================================================
-- SQL Test: Content moderation triggers and constraints
--
-- Issue #587
--
-- Run: psql $DATABASE_URL -f supabase/manual_tests/test_content_moderation.sql
--
-- Safe to run on staging: wrapped in a ROLLBACK transaction.
-- ============================================================

BEGIN;

-- ── Setup ─────────────────────────────────────────────────────────────────────

INSERT INTO auth.users (id, email)
VALUES ('99999999-9999-9999-9999-999999999999'::uuid, 'user_content_mod@example.com')
ON CONFLICT (id) DO NOTHING;

-- Create a pin to comment on
INSERT INTO public.mood_pins (id, sentiment, grid_lat, grid_lon)
VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid, 'happy', 41.0, -75.0);

INSERT INTO public.user_mood_pins (user_id, mood_pin_id)
VALUES ('99999999-9999-9999-9999-999999999999'::uuid, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid);

-- ── Test 1: Comment length limit (max 500 chars) ──────────────────────────────

-- 500-char comment should succeed
DO $$
BEGIN
  INSERT INTO public.mood_pin_comments (mood_pin_id, user_id, text)
  VALUES (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid,
    '99999999-9999-9999-9999-999999999999'::uuid,
    repeat('a', 500)
  );
  RAISE NOTICE 'SUCCESS: 500-char comment accepted';
END;
$$;

-- 501-char comment should be rejected by CHECK constraint
DO $$
BEGIN
  BEGIN
    INSERT INTO public.mood_pin_comments (mood_pin_id, user_id, text)
    VALUES (
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid,
      '99999999-9999-9999-9999-999999999999'::uuid,
      repeat('a', 501)
    );
    RAISE EXCEPTION 'FAIL: 501-char comment should have been rejected';
  EXCEPTION
    WHEN check_violation THEN
      RAISE NOTICE 'SUCCESS: 501-char comment correctly rejected: %', sqlerrm;
  END;
END;
$$;

-- Empty comment should be rejected
DO $$
BEGIN
  BEGIN
    INSERT INTO public.mood_pin_comments (mood_pin_id, user_id, text)
    VALUES (
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid,
      '99999999-9999-9999-9999-999999999999'::uuid,
      ''
    );
    RAISE EXCEPTION 'FAIL: Empty comment should have been rejected';
  EXCEPTION
    WHEN check_violation THEN
      RAISE NOTICE 'SUCCESS: Empty comment correctly rejected: %', sqlerrm;
  END;
END;
$$;

-- ── Test 2: Profanity filter ──────────────────────────────────────────────────

-- Clean comment should succeed
DO $$
BEGIN
  INSERT INTO public.mood_pin_comments (mood_pin_id, user_id, text)
  VALUES (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid,
    '99999999-9999-9999-9999-999999999999'::uuid,
    'This is a totally clean and friendly comment!'
  );
  RAISE NOTICE 'SUCCESS: Clean comment accepted';
END;
$$;

-- Comment with blocklisted word should be rejected
DO $$
BEGIN
  BEGIN
    INSERT INTO public.mood_pin_comments (mood_pin_id, user_id, text)
    VALUES (
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid,
      '99999999-9999-9999-9999-999999999999'::uuid,
      'This comment contains damn inappropriate content'
    );
    RAISE EXCEPTION 'FAIL: Profanity should have been caught';
  EXCEPTION
    WHEN other THEN
      IF sqlerrm LIKE '%inappropriate%' OR sqlerrm LIKE '%Profanity%' THEN
        RAISE NOTICE 'SUCCESS: Profanity filter caught blocked word: %', sqlerrm;
      ELSE
        RAISE EXCEPTION 'FAIL: Unexpected error: %', sqlerrm;
      END IF;
  END;
END;
$$;

-- ── Test 3: Log entry notes length limit (max 2000 chars) ─────────────────────

-- 2000-char note should succeed
DO $$
BEGIN
  INSERT INTO public.log_entries (user_id, date, mood, notes)
  VALUES (
    '99999999-9999-9999-9999-999999999999'::uuid,
    now()::date,
    3,
    repeat('b', 2000)
  );
  RAISE NOTICE 'SUCCESS: 2000-char note accepted';
END;
$$;

-- 2001-char note should be rejected
DO $$
BEGIN
  BEGIN
    INSERT INTO public.log_entries (user_id, date, mood, notes)
    VALUES (
      '99999999-9999-9999-9999-999999999999'::uuid,
      now()::date,
      4,
      repeat('b', 2001)
    );
    RAISE EXCEPTION 'FAIL: 2001-char note should have been rejected';
  EXCEPTION
    WHEN check_violation THEN
      RAISE NOTICE 'SUCCESS: 2001-char note correctly rejected: %', sqlerrm;
  END;
END;
$$;

-- NULL note is fine (no constraint violation)
DO $$
BEGIN
  INSERT INTO public.log_entries (user_id, date, mood, notes)
  VALUES (
    '99999999-9999-9999-9999-999999999999'::uuid,
    now()::date,
    5,
    NULL
  );
  RAISE NOTICE 'SUCCESS: NULL note accepted';
END;
$$;

-- Rollback all test data
ROLLBACK;
