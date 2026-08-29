-- Contract test for leaderboard settlement idempotency.
-- Run against a database with the migrations applied.

BEGIN;

DO $$
DECLARE
  test_user uuid := '77777777-7777-7777-7777-777777777777';
  reward_reason text := 'leaderboard_bonus_rank_1_week_2026-08-24';
BEGIN
  INSERT INTO auth.users (id, email)
  VALUES (test_user, 'leaderboard-idempotency@example.com')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.echo_rewards (user_id, amount, reason)
  VALUES (test_user, 100, reward_reason);

  BEGIN
    INSERT INTO public.echo_rewards (user_id, amount, reason)
    VALUES (test_user, 100, reward_reason);
    RAISE EXCEPTION 'Duplicate leaderboard reward was accepted';
  EXCEPTION
    WHEN unique_violation THEN
      NULL;
  END;
END;
$$;

ROLLBACK;