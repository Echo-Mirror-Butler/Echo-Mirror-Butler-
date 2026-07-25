-- Add user_sessions table for tracking device sessions
-- Populated on login by the app client to enable session management UI

CREATE TABLE IF NOT EXISTS user_sessions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_name   TEXT NOT NULL DEFAULT 'Unknown device',
  user_agent    TEXT,
  last_active   TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own sessions"
  ON user_sessions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own sessions"
  ON user_sessions FOR DELETE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own sessions"
  ON user_sessions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX idx_user_sessions_user ON user_sessions (user_id);

-- Add MFA recovery codes table
-- Stores hashed one-time recovery codes for MFA fallback

CREATE TABLE IF NOT EXISTS mfa_recovery_codes (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  code_hash     TEXT NOT NULL,
  used          BOOLEAN NOT NULL DEFAULT false,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE mfa_recovery_codes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own recovery codes"
  ON mfa_recovery_codes FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own recovery codes"
  ON mfa_recovery_codes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own recovery codes"
  ON mfa_recovery_codes FOR UPDATE
  USING (auth.uid() = user_id);

CREATE INDEX idx_mfa_recovery_codes_user ON mfa_recovery_codes (user_id);
