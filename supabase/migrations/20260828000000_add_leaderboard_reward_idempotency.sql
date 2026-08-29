-- A leaderboard bonus is unique per user and settlement week.
-- The week is encoded in reason so other reward types remain unaffected.
CREATE UNIQUE INDEX IF NOT EXISTS idx_echo_rewards_leaderboard_period_unique
  ON public.echo_rewards (user_id, reason)
  WHERE reason LIKE 'leaderboard_bonus_rank_%_week_%';