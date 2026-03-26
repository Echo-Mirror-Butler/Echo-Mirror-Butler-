-- ============================================================
-- EchoMirror Butler — Seed Data for Wallet and Gift Testing
-- ============================================================
-- These local test users are inserted directly so wallet and gift
-- tables can satisfy their foreign keys during `supabase db reset`.
-- ============================================================

-- Local auth users for wallet and gift test data
insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  raw_app_meta_data,
  raw_user_meta_data,
  is_super_admin,
  is_anonymous
) values
  (
    '00000000-0000-0000-0000-000000000000',
    '11111111-1111-1111-1111-111111111111',
    'authenticated',
    'authenticated',
    'wallet@example.com',
    '$2a$10$abcdefghijklmnopqrstuvwxyzABCDEF1234567890abcdefghi',
    now(),
    now(),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"full_name":"Wallet Test User"}'::jsonb,
    false,
    false
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '22222222-2222-2222-2222-222222222222',
    'authenticated',
    'authenticated',
    'recipient@example.com',
    '$2a$10$abcdefghijklmnopqrstuvwxyzABCDEF1234567890abcdefghi',
    now(),
    now(),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"full_name":"Recipient Test User"}'::jsonb,
    false,
    false
  );

insert into auth.identities (
  provider_id,
  user_id,
  identity_data,
  provider,
  last_sign_in_at,
  created_at,
  updated_at
) values
  (
    'wallet@example.com',
    '11111111-1111-1111-1111-111111111111',
    '{"sub":"11111111-1111-1111-1111-111111111111","email":"wallet@example.com","email_verified":true,"phone_verified":false,"provider":"email","providers":["email"]}'::jsonb,
    'email',
    now(),
    now(),
    now()
  ),
  (
    'recipient@example.com',
    '22222222-2222-2222-2222-222222222222',
    '{"sub":"22222222-2222-2222-2222-222222222222","email":"recipient@example.com","email_verified":true,"phone_verified":false,"provider":"email","providers":["email"]}'::jsonb,
    'email',
    now(),
    now(),
    now()
  );

-- One test wallet for the primary test user
insert into public.user_wallets (user_id, public_key, encrypted_secret) values
  (
    '11111111-1111-1111-1111-111111111111',
    'GAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAWH7',
    'encrypted_secret_for_wallet_test_user'
  );

-- Two sample gift transactions: one sent, one received
insert into public.gift_transactions (
  id,
  sender_user_id,
  recipient_user_id,
  echo_amount,
  stellar_tx_hash,
  message,
  status,
  created_at
) values
  (
    '33333333-3333-3333-3333-333333333333',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222',
    12.5,
    'testhash-sent-001',
    'Welcome to ECHO',
    'completed',
    now()
  ),
  (
    '44444444-4444-4444-4444-444444444444',
    '22222222-2222-2222-2222-222222222222',
    '11111111-1111-1111-1111-111111111111',
    7.25,
    'testhash-received-001',
    'Thanks for the support',
    'completed',
    now()
  );
