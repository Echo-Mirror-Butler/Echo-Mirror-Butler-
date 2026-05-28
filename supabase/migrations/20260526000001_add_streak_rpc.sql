-- Add index for streak calculations
CREATE INDEX IF NOT EXISTS idx_mood_logs_user_created
ON mood_logs(user_id, created_at DESC);

-- Create RPC for calculating streak
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
    v_temp_streak int := 0;
BEGIN
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
        -- A streak is valid if the last log date is today or yesterday
        IF v_last_log_date >= CURRENT_DATE - INTERVAL '1 day' THEN
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
