-- ============================================================
-- Issue #615: Referral / invite-a-friend system
-- ============================================================

-- Table: each user gets a unique referral code
CREATE TABLE IF NOT EXISTS user_referral_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  code text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE user_referral_codes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own referral code"
  ON user_referral_codes FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own referral code"
  ON user_referral_codes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Table: tracks which user was referred by whom
CREATE TABLE IF NOT EXISTS referrals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  referred_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  referral_code text NOT NULL,
  completed boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read referrals they are part of"
  ON referrals FOR SELECT
  USING (auth.uid() = referrer_id OR auth.uid() = referred_id);

CREATE POLICY "Authenticated users can insert referrals"
  ON referrals FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "System can update referrals"
  ON referrals FOR UPDATE
  USING (true);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON referrals(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referred ON referrals(referred_id);
CREATE INDEX IF NOT EXISTS idx_referral_codes_code ON user_referral_codes(code);

-- RPC: generate a unique referral code for the current user
CREATE OR REPLACE FUNCTION generate_referral_code(p_user_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_code text;
  v_existing text;
BEGIN
  -- Check if user already has a code
  SELECT code INTO v_existing FROM user_referral_codes WHERE user_id = p_user_id;
  IF v_existing IS NOT NULL THEN
    RETURN v_existing;
  END IF;

  -- Generate a unique 8-char alphanumeric code
  LOOP
    v_code := upper(substring(md5(random()::text) from 1 for 8));
    EXIT WHEN NOT EXISTS (SELECT 1 FROM user_referral_codes WHERE code = v_code);
  END LOOP;

  INSERT INTO user_referral_codes (user_id, code) VALUES (p_user_id, v_code);
  RETURN v_code;
END;
$$;

-- RPC: apply a referral code when a new user signs up
CREATE OR REPLACE FUNCTION apply_referral(p_referral_code text, p_new_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_referrer_id uuid;
BEGIN
  -- Find the referrer
  SELECT user_id INTO v_referrer_id FROM user_referral_codes WHERE code = upper(p_referral_code);
  IF v_referrer_id IS NULL OR v_referrer_id = p_new_user_id THEN
    RETURN false;
  END IF;

  -- Prevent duplicate referrals
  IF EXISTS (SELECT 1 FROM referrals WHERE referred_id = p_new_user_id) THEN
    RETURN false;
  END IF;

  -- Record the referral
  INSERT INTO referrals (referrer_id, referred_id, referral_code, completed)
  VALUES (v_referrer_id, p_new_user_id, upper(p_referral_code), true);

  -- Reward: grant 2 ECHO to both referrer and referred (if echo_rewards and user_wallets exist)
  BEGIN
    INSERT INTO echo_rewards (user_id, amount, reason) VALUES (v_referrer_id, 2, 'referral_bonus');
    INSERT INTO echo_rewards (user_id, amount, reason) VALUES (p_new_user_id, 2, 'referral_signup_bonus');
    UPDATE user_wallets SET balance = balance + 2, updated_at = now() WHERE user_id = v_referrer_id;
    UPDATE user_wallets SET balance = balance + 2, updated_at = now() WHERE user_id = p_new_user_id;
  EXCEPTION WHEN OTHERS THEN
    -- If echo_rewards or user_wallets tables don't exist yet, skip rewards
    NULL;
  END;

  RETURN true;
END;
$$;

-- RPC: get referral stats for a user
CREATE OR REPLACE FUNCTION get_referral_stats(p_user_id uuid)
RETURNS TABLE (code text, total_referrals bigint, completed_referrals bigint)
LANGUAGE SQL
SECURITY DEFINER
AS $$
  SELECT
    (SELECT code FROM user_referral_codes WHERE user_id = p_user_id),
    COALESCE((SELECT COUNT(*) FROM referrals WHERE referrer_id = p_user_id), 0)::bigint,
    COALESCE((SELECT COUNT(*) FROM referrals WHERE referrer_id = p_user_id AND completed = true), 0)::bigint;
$$;
