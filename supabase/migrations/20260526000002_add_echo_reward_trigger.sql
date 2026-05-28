CREATE TABLE IF NOT EXISTS echo_rewards (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id),
    amount integer NOT NULL,
    reason text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- Index to prevent full table scan when checking for daily farming
CREATE INDEX IF NOT EXISTS idx_echo_rewards_user_created 
ON echo_rewards(user_id, created_at);

-- Enable RLS
ALTER TABLE echo_rewards ENABLE ROW LEVEL SECURITY;

-- Allow users to read their own rewards
CREATE POLICY "Users can view own rewards"
ON echo_rewards FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION grant_echo_reward()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_today date := CURRENT_DATE;
    v_reward_count int;
    v_streak json;
    v_current_streak int;
    v_reward_amount int := 1;
    v_reason text := 'daily_mood_log';
BEGIN
    -- Prevent farming: Check if user already got a reward for a mood log today
    SELECT count(*)
    INTO v_reward_count
    FROM echo_rewards
    WHERE user_id = NEW.user_id 
      AND created_at::date = v_today
      AND reason IN ('daily_mood_log', '7_day_streak_bonus');

    IF v_reward_count > 0 THEN
        RETURN NEW; -- Already rewarded today
    END IF;

    -- Check streak for bonus
    -- Since this is AFTER INSERT, get_current_streak includes the new log
    v_streak := get_current_streak(NEW.user_id);
    v_current_streak := COALESCE((v_streak->>'current_streak')::int, 0);

    IF v_current_streak > 0 AND v_current_streak % 7 = 0 THEN
        v_reward_amount := 5;
        v_reason := '7_day_streak_bonus';
    END IF;

    -- Insert reward
    INSERT INTO echo_rewards (user_id, amount, reason)
    VALUES (NEW.user_id, v_reward_amount, v_reason);

    -- Update wallet atomically
    UPDATE user_wallets
    SET balance = balance + v_reward_amount,
        updated_at = now()
    WHERE user_id = NEW.user_id;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_mood_log_insert_reward ON mood_logs;
CREATE TRIGGER on_mood_log_insert_reward
AFTER INSERT ON mood_logs
FOR EACH ROW
EXECUTE FUNCTION grant_echo_reward();
