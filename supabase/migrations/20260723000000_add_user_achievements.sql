-- Issue #521: achievement badges with milestone celebrations and ECHO rewards

CREATE TABLE IF NOT EXISTS public.user_achievements (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  achievement_id text NOT NULL,
  unlocked_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, achievement_id)
);

CREATE INDEX IF NOT EXISTS idx_user_achievements_user
  ON public.user_achievements(user_id);

ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  CREATE POLICY "users read own" ON public.user_achievements
    FOR SELECT USING (auth.uid() = user_id);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- No client INSERT policy: rows are written only by the unlock_achievement
-- RPC below, which verifies the achievement was actually earned.

-- Unlocks an achievement for the calling user and credits the milestone
-- ECHO bonus in the same transaction. Each achievement is re-derived from
-- server-side data before unlocking, so clients cannot claim badges or
-- rewards they have not earned. Streaks and habit runs are computed from
-- log_entries (the table all log flows write to; mood_logs is unwritten).
-- global_citizen is the one exception: mood pins are anonymous, so it is
-- client-attested, and it carries no ECHO reward.
-- Returns whether this call performed the unlock, so the client can fire
-- the celebration only on first unlock.
CREATE OR REPLACE FUNCTION public.unlock_achievement(p_achievement_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_reward integer;
    v_needed_streak integer := 0;
    v_earned boolean := false;
    v_inserted boolean := false;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Not authenticated'
        );
    END IF;

    v_reward := CASE p_achievement_id
        WHEN 'first_log' THEN 0
        WHEN 'week_warrior' THEN 10
        WHEN 'month_master' THEN 50
        WHEN 'century' THEN 200
        WHEN 'insight_seeker' THEN 0
        WHEN 'echo_gifter' THEN 0
        WHEN 'habit_hero' THEN 0
        WHEN 'global_citizen' THEN 0
        ELSE NULL
    END;

    IF v_reward IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Unknown achievement'
        );
    END IF;

    CASE p_achievement_id
        WHEN 'first_log' THEN
            v_earned := EXISTS (
                SELECT 1 FROM public.log_entries WHERE user_id = v_user_id
            );
        WHEN 'week_warrior' THEN
            v_needed_streak := 7;
        WHEN 'month_master' THEN
            v_needed_streak := 30;
        WHEN 'century' THEN
            v_needed_streak := 100;
        WHEN 'insight_seeker' THEN
            v_earned := EXISTS (
                SELECT 1 FROM public.ai_insights WHERE user_id = v_user_id
            );
        WHEN 'echo_gifter' THEN
            v_earned := EXISTS (
                SELECT 1 FROM public.gift_transactions
                WHERE sender_user_id = v_user_id
            );
        WHEN 'habit_hero' THEN
            -- Longest run of consecutive days on which the same habit was
            -- logged (gaps-and-islands over distinct habit/day pairs).
            SELECT COALESCE(MAX(run_length), 0) >= 10 INTO v_earned
            FROM (
                SELECT count(*) AS run_length
                FROM (
                    SELECT habit,
                           d - (row_number() OVER (PARTITION BY habit ORDER BY d))::int AS grp
                    FROM (
                        SELECT DISTINCT jsonb_array_elements_text(habits) AS habit,
                                        date::date AS d
                        FROM public.log_entries
                        WHERE user_id = v_user_id
                    ) days
                ) grouped
                GROUP BY habit, grp
            ) runs;
        WHEN 'global_citizen' THEN
            v_earned := true;
    END CASE;

    IF v_needed_streak > 0 THEN
        -- A current streak of N days implies a run of N consecutive log
        -- days, so checking the longest run validates the claim without
        -- rejecting streaks kept alive by freezes or timezone edges.
        SELECT COALESCE(MAX(run_length), 0) >= v_needed_streak INTO v_earned
        FROM (
            SELECT count(*) AS run_length
            FROM (
                SELECT d - (row_number() OVER (ORDER BY d))::int AS grp
                FROM (
                    SELECT DISTINCT date::date AS d
                    FROM public.log_entries
                    WHERE user_id = v_user_id
                ) days
            ) grouped
            GROUP BY grp
        ) runs;
    END IF;

    IF NOT v_earned THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Achievement not earned'
        );
    END IF;

    INSERT INTO public.user_achievements (user_id, achievement_id)
    VALUES (v_user_id, p_achievement_id)
    ON CONFLICT (user_id, achievement_id) DO NOTHING;

    v_inserted := FOUND;

    IF v_inserted AND v_reward > 0 THEN
        INSERT INTO public.echo_rewards (user_id, amount, reason)
        VALUES (v_user_id, v_reward, 'achievement_' || p_achievement_id);

        -- Upsert: the wallet row is created lazily when the user links or
        -- creates a Stellar wallet, so it may not exist yet.
        INSERT INTO public.user_wallets (user_id, balance)
        VALUES (v_user_id, v_reward)
        ON CONFLICT (user_id) DO UPDATE
        SET balance = user_wallets.balance + EXCLUDED.balance,
            updated_at = now();
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'newly_unlocked', v_inserted,
        'reward', CASE WHEN v_inserted THEN v_reward ELSE 0 END
    );
END;
$$;
