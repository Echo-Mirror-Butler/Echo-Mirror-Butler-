-- ============================================================
-- EchoMirror Butler — Seed Data for Local Development
-- ============================================================
-- Note: Auth users are usually created via the Supabase Auth API.
-- These local test users are inserted directly so wallet and gift
-- tables can satisfy their foreign keys during `supabase db reset`.
-- ============================================================

-- Sample mood pins (anonymous, no user_id required)
insert into public.mood_pins (sentiment, grid_lat, grid_lon) values
  ('happy', 37.8, -122.4),
  ('calm', 37.7, -122.5),
  ('anxious', 37.9, -122.3),
  ('grateful', 37.8, -122.5),
  ('stressed', 37.7, -122.4),
  ('excited', 37.9, -122.5);

-- Sample video posts (public feed)
insert into public.video_posts (video_url, mood_tag) values
  ('https://example.com/sample-video-1.mp4', 'happy'),
  ('https://example.com/sample-video-2.mp4', 'calm'),
  ('https://example.com/sample-video-3.mp4', 'motivated');

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
