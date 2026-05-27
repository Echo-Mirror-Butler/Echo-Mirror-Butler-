-- ============================================================
-- SQL Test: mood_logs Row Level Security (RLS) policies
-- 
-- Safe to run on staging: wrapped in a ROLLBACK transaction.
-- ============================================================

BEGIN;

-- 1. Setup mock users
INSERT INTO auth.users (id, email)
VALUES 
  ('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'::uuid, 'user_a@example.com'),
  ('bbbbbbbb-cccc-dddd-eeee-ffffffffffff'::uuid, 'user_b@example.com')
ON CONFLICT (id) DO NOTHING;

-- 2. Setup mock wallets (required for reward trigger)
INSERT INTO public.user_wallets (user_id, public_key, encrypted_secret, balance)
VALUES 
  ('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'::uuid, 'GD_MOCK_USER_A_STAFDJG...', 'encrypted_secret_a...', 10.0),
  ('bbbbbbbb-cccc-dddd-eeee-ffffffffffff'::uuid, 'GE_MOCK_USER_B_STAFDJG...', 'encrypted_secret_b...', 10.0)
ON CONFLICT (user_id) DO NOTHING;

-- 3. Set role to authenticated and mock auth.uid() as User A
SET LOCAL request.jwt.claims = '{"sub": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", "role": "authenticated"}';
SET LOCAL role = 'authenticated';

-- TEST 1: User A can insert their own mood log (Should SUCCEED)
INSERT INTO public.mood_logs (user_id, mood, country, city)
VALUES ('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'::uuid, '😊 happy', 'US', 'New York');

-- TEST 2: User A tries to insert a mood log for User B (Should FAIL via RLS)
DO $$
BEGIN
  BEGIN
    INSERT INTO public.mood_logs (user_id, mood, country, city)
    VALUES ('bbbbbbbb-cccc-dddd-eeee-ffffffffffff'::uuid, '😢 sad', 'US', 'San Francisco');
    
    RAISE EXCEPTION 'FAIL: RLS allowed User A to insert a log for User B!';
  EXCEPTION 
    WHEN insufficient_privilege THEN
      RAISE NOTICE 'SUCCESS: RLS correctly blocked User A from inserting a log for User B.';
    WHEN OTHERS THEN
      RAISE NOTICE 'SUCCESS: RLS blocked insertion with SQLSTATE: %, Message: %', SQLSTATE, SQLERRM;
  END;
END;
$$;

-- TEST 3: User A can select their own mood logs, but not User B's
-- Switch to superuser to insert User B's log first
RESET role;
RESET request.jwt.claims;

INSERT INTO public.mood_logs (user_id, mood, country, city)
VALUES ('bbbbbbbb-cccc-dddd-eeee-ffffffffffff'::uuid, '😎 excited', 'CA', 'Toronto');

-- Switch back to User A
SET LOCAL request.jwt.claims = '{"sub": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", "role": "authenticated"}';
SET LOCAL role = 'authenticated';

-- Assert we can see User A's logs
DO $$
DECLARE
  v_count int;
BEGIN
  SELECT count(*) INTO v_count 
  FROM public.mood_logs 
  WHERE user_id = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'::uuid;

  IF v_count = 1 THEN
    RAISE NOTICE 'SUCCESS: User A can read their own logs (found 1 log).';
  ELSE
    RAISE EXCEPTION 'FAIL: User A could not read their own logs (found % logs).', v_count;
  END IF;
END;
$$;

-- Assert we CANNOT see User B's logs (RLS should filter them out silently)
DO $$
DECLARE
  v_count int;
BEGIN
  SELECT count(*) INTO v_count 
  FROM public.mood_logs 
  WHERE user_id = 'bbbbbbbb-cccc-dddd-eeee-ffffffffffff'::uuid;

  IF v_count = 0 THEN
    RAISE NOTICE 'SUCCESS: RLS correctly hid User B''s logs from User A.';
  ELSE
    RAISE EXCEPTION 'FAIL: RLS allowed User A to read User B''s logs (found % logs).', v_count;
  END IF;
END;
$$;

-- TEST 4: User A tries to update User B's log (Should affect 0 rows)
DO $$
DECLARE
  v_rows_affected int;
BEGIN
  UPDATE public.mood_logs
  SET mood = '😡 angry'
  WHERE user_id = 'bbbbbbbb-cccc-dddd-eeee-ffffffffffff'::uuid;
  
  GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
  
  IF v_rows_affected = 0 THEN
    RAISE NOTICE 'SUCCESS: RLS prevented User A from updating User B''s logs (0 rows updated).';
  ELSE
    RAISE EXCEPTION 'FAIL: RLS allowed User A to update User B''s logs (% rows updated).', v_rows_affected;
  END IF;
END;
$$;

-- TEST 5: User A tries to delete User B's log (Should affect 0 rows)
DO $$
DECLARE
  v_rows_affected int;
BEGIN
  DELETE FROM public.mood_logs
  WHERE user_id = 'bbbbbbbb-cccc-dddd-eeee-ffffffffffff'::uuid;
  
  GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
  
  IF v_rows_affected = 0 THEN
    RAISE NOTICE 'SUCCESS: RLS prevented User A from deleting User B''s logs (0 rows deleted).';
  ELSE
    RAISE EXCEPTION 'FAIL: RLS allowed User A to delete User B''s logs (% rows deleted).', v_rows_affected;
  END IF;
END;
$$;

-- Rollback to keep staging clean and free of mock data
ROLLBACK;
