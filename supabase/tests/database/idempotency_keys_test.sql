-- Tests for idempotency_keys table and purge_expired_idempotency_keys() function
-- Issue #639: Ensure idempotency key storage, deduplication, and expiry work correctly.
--
-- Run with: supabase test db

create extension if not exists pgtap with schema extensions;

select plan(10);

-- ── Fixtures ──────────────────────────────────────────────────────────────────

-- Two test users
insert into auth.users (id, aud, role, email, created_at, updated_at)
values
  ('00000000-0000-4000-8000-000000000201', 'authenticated', 'authenticated', 'idempotency-alice@example.test', now(), now()),
  ('00000000-0000-4000-8000-000000000202', 'authenticated', 'authenticated', 'idempotency-bob@example.test',   now(), now());

-- ── 1. Table exists ───────────────────────────────────────────────────────────

select has_table(
  'public',
  'idempotency_keys',
  'idempotency_keys table should exist'
);

-- ── 2. Required columns exist ─────────────────────────────────────────────────

select has_column('public', 'idempotency_keys', 'user_id',         'column user_id exists');
select has_column('public', 'idempotency_keys', 'function_name',   'column function_name exists');
select has_column('public', 'idempotency_keys', 'idempotency_key', 'column idempotency_key exists');
select has_column('public', 'idempotency_keys', 'response_status', 'column response_status exists');
select has_column('public', 'idempotency_keys', 'response_body',   'column response_body exists');
select has_column('public', 'idempotency_keys', 'expires_at',      'column expires_at exists');

-- ── 3. Store and retrieve a result ────────────────────────────────────────────

insert into public.idempotency_keys (
  user_id,
  function_name,
  idempotency_key,
  response_status,
  response_body
) values (
  '00000000-0000-4000-8000-000000000201',
  'send-echo',
  'test-key-abc-123',
  201,
  '{"success": true, "stellar_tx_hash": "FAKEHASH001"}'::jsonb
);

select is(
  (
    select response_status
    from public.idempotency_keys
    where user_id        = '00000000-0000-4000-8000-000000000201'
      and function_name  = 'send-echo'
      and idempotency_key = 'test-key-abc-123'
  ),
  201,
  'Stored idempotency result should be retrievable with correct status'
);

-- ── 4. Unique constraint prevents duplicate keys for same (user, fn, key) ─────

-- Attempt to insert a second row with the same (user_id, function_name, idempotency_key)
-- This MUST raise a unique violation.
select throws_ok(
  $$
    insert into public.idempotency_keys (
      user_id,
      function_name,
      idempotency_key,
      response_status,
      response_body
    ) values (
      '00000000-0000-4000-8000-000000000201',
      'send-echo',
      'test-key-abc-123',
      201,
      '{"success": true, "stellar_tx_hash": "FAKEHASH002"}'::jsonb
    )
  $$,
  '23505',
  'duplicate key value violates unique constraint "idempotency_keys_user_fn_key_uniq"',
  'Duplicate (user_id, function_name, idempotency_key) should raise unique constraint violation'
);

-- ── 5. Same key for a DIFFERENT user is allowed ───────────────────────────────

-- Bob can use the same key string as Alice — they are independent.
insert into public.idempotency_keys (
  user_id,
  function_name,
  idempotency_key,
  response_status,
  response_body
) values (
  '00000000-0000-4000-8000-000000000202',
  'send-echo',
  'test-key-abc-123',
  201,
  '{"success": true, "stellar_tx_hash": "FAKEHASH003"}'::jsonb
);

select is(
  (
    select count(*)::integer
    from public.idempotency_keys
    where idempotency_key = 'test-key-abc-123'
      and function_name   = 'send-echo'
  ),
  2,
  'Same idempotency key string used by two different users should produce two distinct rows'
);

-- ── 6. purge_expired_idempotency_keys() removes only expired rows ─────────────

-- Insert one already-expired row
insert into public.idempotency_keys (
  user_id,
  function_name,
  idempotency_key,
  response_status,
  response_body,
  expires_at
) values (
  '00000000-0000-4000-8000-000000000201',
  'send-echo',
  'expired-key-xyz',
  201,
  '{"success": true}'::jsonb,
  now() - interval '1 second'   -- already expired
);

-- Confirm it exists before purge
select is(
  (
    select count(*)::integer
    from public.idempotency_keys
    where idempotency_key = 'expired-key-xyz'
  ),
  1,
  'Expired row should exist before purge'
);

-- Run the purge function
perform public.purge_expired_idempotency_keys();

-- The expired row must be gone
select is(
  (
    select count(*)::integer
    from public.idempotency_keys
    where idempotency_key = 'expired-key-xyz'
  ),
  0,
  'Expired row should be deleted after purge_expired_idempotency_keys()'
);

-- Non-expired rows must survive
select is(
  (
    select count(*)::integer
    from public.idempotency_keys
    where idempotency_key = 'test-key-abc-123'
  ),
  2,
  'Non-expired rows should survive purge_expired_idempotency_keys()'
);

select * from finish();
