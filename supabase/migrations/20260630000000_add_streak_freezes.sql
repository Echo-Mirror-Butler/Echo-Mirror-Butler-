-- Create streak_freezes table for Issue #505
-- Allows users to spend ECHO to protect their streak from one missed day

CREATE TABLE IF NOT EXISTS streak_freezes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  used_on_date DATE NOT NULL,
  echo_cost   NUMERIC NOT NULL DEFAULT 5,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS: users can only read/insert their own freezes
ALTER TABLE streak_freezes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own freezes"
  ON streak_freezes FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own freezes"
  ON streak_freezes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Index for fast freeze lookup
CREATE INDEX idx_streak_freezes_user_date
  ON streak_freezes (user_id, used_on_date);

-- Enforce max 1 freeze per 7-day window
CREATE OR REPLACE FUNCTION check_freeze_rate_limit()
RETURNS TRIGGER AS $$
BEGIN
  IF (
    SELECT COUNT(*)
    FROM streak_freezes
    WHERE user_id = NEW.user_id
      AND created_at >= NEW.created_at - INTERVAL '7 days'
  ) > 1 THEN
    RAISE EXCEPTION 'Maximum 1 freeze per 7-day window';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_check_freeze_rate_limit
  BEFORE INSERT ON streak_freezes
  FOR EACH ROW
  EXECUTE FUNCTION check_freeze_rate_limit();

-- Enforce same day cannot be frozen twice
CREATE UNIQUE INDEX idx_streak_freezes_unique_day
  ON streak_freezes (user_id, used_on_date);

-- Modify calculate_streak to skip frozen dates
CREATE OR REPLACE FUNCTION calculate_streak(p_user_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
    v_current_streak int := 0;
    v_longest_streak int := 0;
    v_last_log_date date;
    v_dates date[];
    v_frozen_dates date[];
    v_temp_streak int := 0;
    v_is_frozen bool;
BEGIN
    SELECT array_agg(f.used_on_date) INTO v_frozen_dates
    FROM streak_freezes f
    WHERE f.user_id = p_user_id;

    -- Get all distinct dates in descending order (newest first)
    SELECT array_agg(d.log_date)
    INTO v_dates
    FROM (
        SELECT DISTINCT created_at::date AS log_date
        FROM mood_logs
        WHERE mood_logs.user_id = p_user_id
        ORDER BY created_at::date DESC
    ) d;

    IF v_dates IS NOT NULL AND array_length(v_dates, 1) > 0 THEN
        v_last_log_date := v_dates[1];

        -- Calculate current streak
        -- A streak is valid if the last log date is today or yesterday,
        -- OR if today is frozen (allow streak to continue one extra day)
        v_is_frozen := v_frozen_dates IS NOT NULL AND CURRENT_DATE = ANY(v_frozen_dates);

        IF v_last_log_date >= CURRENT_DATE - INTERVAL '1 day' OR v_is_frozen THEN
            v_current_streak := 1;
            IF array_length(v_dates, 1) >= 2 THEN
                FOR i IN 2..array_length(v_dates, 1) LOOP
                    IF v_dates[i] = v_dates[i-1] - INTERVAL '1 day' THEN
                        v_current_streak := v_current_streak + 1;
                    ELSE
                        EXIT;
                    END IF;
                END LOOP;
            END IF;
        END IF;

        -- Calculate longest streak
        v_temp_streak := 1;
        v_longest_streak := 1;
        IF array_length(v_dates, 1) >= 2 THEN
            FOR i IN 2..array_length(v_dates, 1) LOOP
                IF v_dates[i] = v_dates[i-1] - INTERVAL '1 day' THEN
                    v_temp_streak := v_temp_streak + 1;
                ELSE
                    v_temp_streak := 1;
                END IF;
                IF v_temp_streak > v_longest_streak THEN
                    v_longest_streak := v_temp_streak;
                END IF;
            END LOOP;
        END IF;
    END IF;

    RETURN json_build_object(
        'current_streak', v_current_streak,
        'longest_streak', v_longest_streak,
        'last_log_date', v_last_log_date
    );
END;
$$;
