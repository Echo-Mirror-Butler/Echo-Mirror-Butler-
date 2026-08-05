-- Migration: Add idempotency_keys table for safe request deduplication
-- Issue #639: Mutating edge functions (send-echo) must not re-execute on retried requests.
--
-- The client supplies an `Idempotency-Key` header. The edge function stores
-- the result the first time it processes the key. Subsequent requests with the
-- same key receive the cached result without re-executing any side-effects.
--
-- TTL: 24 hours. Keys are scoped per (user_id, function_name, idempotency_key)
-- so one user's keys cannot collide with another's.

-- ── Table ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.idempotency_keys (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- The edge function that processed this request (e.g. 'send-echo')
  function_name    text        NOT NULL,
  -- Client-supplied key; a UUID4 is recommended but any non-empty string ≤ 255 chars works
  idempotency_key  text        NOT NULL CHECK (char_length(idempotency_key) BETWEEN 1 AND 255),
  -- HTTP status that was returned for the original request
  response_status  integer     NOT NULL,
  -- Full JSON response body stored so we can replay it exactly
  response_body    jsonb       NOT NULL,
  created_at       timestamptz NOT NULL DEFAULT now(),
  -- Default 24-hour expiry; expired rows are pruned by the cleanup function below
  expires_at       timestamptz NOT NULL DEFAULT now() + INTERVAL '24 hours',

  -- One canonical result per (user, function, key)
  CONSTRAINT idempotency_keys_user_fn_key_uniq
    UNIQUE (user_id, function_name, idempotency_key)
);

-- ── Indexes ────────────────────────────────────────────────────────────────
-- Primary lookup path: exact match on (user_id, function_name, idempotency_key)
CREATE INDEX IF NOT EXISTS idx_idempotency_keys_lookup
  ON public.idempotency_keys (user_id, function_name, idempotency_key);

-- Used by the cleanup job to efficiently find and delete expired rows
CREATE INDEX IF NOT EXISTS idx_idempotency_keys_expires_at
  ON public.idempotency_keys (expires_at);

-- ── Row-Level Security ─────────────────────────────────────────────────────
ALTER TABLE public.idempotency_keys ENABLE ROW LEVEL SECURITY;

-- Edge functions always run with the service-role key (bypasses RLS),
-- so a single permissive service-role policy is sufficient.
-- Regular authenticated users cannot read or write this table directly.
DO $$
BEGIN
  CREATE POLICY "Service role manages idempotency_keys"
    ON public.idempotency_keys
    FOR ALL
    USING (true)
    WITH CHECK (true);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- ── Cleanup RPC ────────────────────────────────────────────────────────────
-- Call this periodically (e.g. via pg_cron) to remove expired keys and keep
-- the table small. Returns the count of deleted rows.
CREATE OR REPLACE FUNCTION public.purge_expired_idempotency_keys()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted integer;
BEGIN
  DELETE FROM public.idempotency_keys
  WHERE expires_at < now();

  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  RETURN v_deleted;
END;
$$;

COMMENT ON FUNCTION public.purge_expired_idempotency_keys() IS
  'Deletes idempotency_keys rows whose TTL has passed. '
  'Safe to call repeatedly; intended for a pg_cron job.';

-- ── Optional: schedule daily cleanup if pg_cron is available ──────────────
-- Uncomment the block below on a Supabase project where pg_cron is enabled.
--
-- SELECT cron.schedule(
--   'purge-expired-idempotency-keys',
--   '0 3 * * *',   -- 03:00 UTC daily
--   $$SELECT public.purge_expired_idempotency_keys()$$
-- );
