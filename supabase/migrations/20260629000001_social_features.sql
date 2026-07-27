-- Social features: user_follows, privacy, and encouragement

-- ── user_follows table ──────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS user_follows (
  id BIGSERIAL PRIMARY KEY,
  follower_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  following_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(follower_id, following_id)
);

ALTER TABLE user_follows ENABLE ROW LEVEL SECURITY;

-- Users can read follows where they are the follower or the following
CREATE POLICY "users_can_read_own_follows"
  ON user_follows
  FOR SELECT
  USING (auth.uid() = follower_id OR auth.uid() = following_id);

-- Only authenticated users can insert follows (as the follower)
CREATE POLICY "users_can_follow"
  ON user_follows
  FOR INSERT
  WITH CHECK (auth.uid() = follower_id);

-- Only the follower can unfollow
CREATE POLICY "users_can_unfollow"
  ON user_follows
  FOR DELETE
  USING (auth.uid() = follower_id);

-- ── Add public_profile column to profiles ──────────────────────────────────────

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS public_profile BOOLEAN NOT NULL DEFAULT true;

-- ── RPC to get followed users' recent mood logs ────────────────────────────────

CREATE OR REPLACE FUNCTION get_friends_mood_logs(p_user_id UUID, p_days INT DEFAULT 1)
RETURNS TABLE (
  user_id UUID,
  display_name TEXT,
  avatar_url TEXT,
  mood INT,
  date DATE,
  has_public_profile BOOLEAN
)
LANGUAGE SQL
SECURITY DEFINER
AS $$
  SELECT
    p.id,
    p.display_name,
    p.avatar_url,
    le.mood,
    le.date::DATE,
    p.public_profile
  FROM user_follows uf
  JOIN profiles p ON p.id = uf.following_id
  JOIN log_entries le ON le.user_id = uf.following_id
  WHERE uf.follower_id = p_user_id
    AND le.date >= CURRENT_DATE - (p_days || ' days')::INTERVAL
  ORDER BY le.date DESC, le.created_at DESC;
$$;

-- ── RPC to get followers count ──────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION get_followers_count(p_user_id UUID)
RETURNS INT
LANGUAGE SQL
SECURITY DEFINER
AS $$
  SELECT COUNT(*)::INT FROM user_follows WHERE following_id = p_user_id;
$$;

-- ── RPC to get following count ──────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION get_following_count(p_user_id UUID)
RETURNS INT
LANGUAGE SQL
SECURITY DEFINER
AS $$
  SELECT COUNT(*)::INT FROM user_follows WHERE follower_id = p_user_id;
$$;

-- ── RPC to get mood pins from followed users with public profiles ──────────────

CREATE OR REPLACE FUNCTION get_following_mood_pins(p_user_id UUID)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  grid_lat FLOAT8,
  grid_lon FLOAT8,
  sentiment TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE SQL
SECURITY DEFINER
AS $$
  SELECT mp.id, ump.user_id, mp.grid_lat, mp.grid_lon, mp.sentiment, mp.created_at
  FROM user_follows uf
  JOIN user_mood_pins ump ON ump.user_id = uf.following_id
  JOIN mood_pins mp ON mp.id = ump.mood_pin_id
  JOIN profiles p ON p.id = ump.user_id AND p.public_profile = true
  WHERE uf.follower_id = p_user_id
  ORDER BY mp.created_at DESC
  LIMIT 500;
$$;
