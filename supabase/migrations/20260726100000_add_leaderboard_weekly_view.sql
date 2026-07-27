-- ============================================================
-- Issue #597: Weekly leaderboard with anonymous masking
-- The view conditionally masks display_name/avatar_url for
-- users who have opted into anonymous mode. Each viewer only
-- sees their own real identity; everyone else sees masked data.
-- ============================================================

-- Add leaderboard_anonymous column to profiles if it doesn't exist
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS leaderboard_anonymous boolean NOT NULL DEFAULT false;

-- Drop the view if it already exists (safe re-creation)
DROP VIEW IF EXISTS leaderboard_weekly;

-- Create the leaderboard_weekly view with CASE-based anonymous masking
CREATE OR REPLACE VIEW leaderboard_weekly AS
SELECT
  p.id,
  -- Show real name only to the user themselves; mask for everyone else
  CASE
    WHEN p.leaderboard_anonymous = true AND p.id <> auth.uid()
    THEN 'Anonymous'
    ELSE COALESCE(p.display_name, 'User')
  END AS display_name,
  -- Show real avatar only to the user themselves; placeholder for everyone else
  CASE
    WHEN p.leaderboard_anonymous = true AND p.id <> auth.uid()
    THEN NULL
    ELSE p.avatar_url
  END AS avatar_url,
  COALESCE(p.leaderboard_anonymous, false) AS leaderboard_anonymous,
  COALESCE(SUM(er.amount), 0)::numeric AS echo_earned_this_week,
  RANK() OVER (ORDER BY COALESCE(SUM(er.amount), 0) DESC)::int AS rank
FROM profiles p
LEFT JOIN echo_rewards er
  ON er.user_id = p.id
  AND er.created_at >= date_trunc('week', now() AT TIME ZONE 'UTC')
GROUP BY p.id, p.display_name, p.avatar_url, p.leaderboard_anonymous;

-- Allow any authenticated user to read the view
GRANT SELECT ON leaderboard_weekly TO authenticated;

-- Migration test: verify anonymous masking works
DO $$
DECLARE
  _anon_display_name text;
BEGIN
  -- This is a structural check: the view should exist and be queryable
  -- Actual RLS + masking is verified by querying as different users,
  -- which requires Supabase test infrastructure.
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.views
    WHERE table_name = 'leaderboard_weekly'
  ) THEN
    RAISE EXCEPTION 'leaderboard_weekly view was not created';
  END IF;
END $$;
