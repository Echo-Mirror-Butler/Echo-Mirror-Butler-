-- Create user_achievements table for tracking unlocked achievements
CREATE TABLE user_achievements (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  achievement_id text NOT NULL,
  unlocked_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, achievement_id)
);

-- Enable Row Level Security
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own achievements
CREATE POLICY "users read own" ON user_achievements FOR SELECT USING (auth.uid() = user_id);

-- Policy: Users can insert their own achievements (triggered by system)
CREATE POLICY "users insert own" ON user_achievements FOR INSERT WITH CHECK (auth.uid() = user_id);
