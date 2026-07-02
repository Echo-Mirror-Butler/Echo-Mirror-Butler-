-- Add leaderboard_anonymous column to profiles table if it doesn't exist
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS leaderboard_anonymous boolean NOT NULL DEFAULT false;

-- Define the leaderboard_weekly view
CREATE OR REPLACE VIEW leaderboard_weekly AS
SELECT
  p.id,
  p.display_name,
  p.avatar_url,
  COALESCE(p.leaderboard_anonymous, false) AS leaderboard_anonymous,
  COALESCE(SUM(er.amount), 0)::numeric      AS echo_earned_this_week,
  RANK() OVER (ORDER BY COALESCE(SUM(er.amount), 0) DESC)::int AS rank
FROM profiles p
LEFT JOIN echo_rewards er
  ON er.user_id = p.id
  AND er.created_at >= date_trunc('week', now() AT TIME ZONE 'UTC')
GROUP BY p.id, p.display_name, p.avatar_url, p.leaderboard_anonymous;

-- Add RLS — the view should be readable by any authenticated user
GRANT SELECT ON leaderboard_weekly TO authenticated;
