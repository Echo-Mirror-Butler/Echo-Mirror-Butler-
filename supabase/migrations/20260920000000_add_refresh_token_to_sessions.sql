-- Add refresh_token_id column to user_sessions for proper session revocation
-- This stores the auth session's refresh token ID to enable individual session revocation

ALTER TABLE user_sessions 
ADD COLUMN IF NOT EXISTS refresh_token_id TEXT;

CREATE INDEX IF NOT EXISTS idx_user_sessions_refresh_token 
ON user_sessions (refresh_token_id);

COMMENT ON COLUMN user_sessions.refresh_token_id IS 
  'Supabase auth refresh token ID for this session, used for revocation';
