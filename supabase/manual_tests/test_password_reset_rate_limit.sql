-- Manual test: password reset auth rate limit (Issue #633)
-- Run inside a transaction and ROLLBACK so nothing persists.

BEGIN;

-- Under limit: first 3 calls for same key succeed
DO $$
DECLARE
  allowed boolean;
BEGIN
  SELECT public.check_auth_rate_limit('email:test-hash', 'password_reset', 3, 60)
    INTO allowed;
  ASSERT allowed IS TRUE, '1st attempt should be allowed';

  SELECT public.check_auth_rate_limit('email:test-hash', 'password_reset', 3, 60)
    INTO allowed;
  ASSERT allowed IS TRUE, '2nd attempt should be allowed';

  SELECT public.check_auth_rate_limit('email:test-hash', 'password_reset', 3, 60)
    INTO allowed;
  ASSERT allowed IS TRUE, '3rd attempt should be allowed';

  SELECT public.check_auth_rate_limit('email:test-hash', 'password_reset', 3, 60)
    INTO allowed;
  ASSERT allowed IS FALSE, '4th attempt should be rate limited';
END $$;

-- Different key is independent
DO $$
DECLARE
  allowed boolean;
BEGIN
  SELECT public.check_auth_rate_limit('ip:1.2.3.4', 'password_reset', 10, 60)
    INTO allowed;
  ASSERT allowed IS TRUE, 'IP key should start fresh';
END $$;

ROLLBACK;
