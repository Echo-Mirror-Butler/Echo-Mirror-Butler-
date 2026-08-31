-- Add habit streak calculation function
-- Follows the same pattern as calculate_streak but specifically for habit logging
CREATE OR REPLACE FUNCTION calculate_habit_streak(p_user_id UUID)
RETURNS TABLE (
  current_streak INT,
  longest_streak INT,
  last_log_date DATE
) AS $$
DECLARE
  v_current_streak INT := 0;
  v_longest_streak INT := 0;
  v_last_log_date DATE;
  v_streak_count INT := 0;
  v_prev_date DATE;
  rec RECORD;
BEGIN
  -- Get all dates where user logged at least one habit, ordered desc
  FOR rec IN
    SELECT DISTINCT date
    FROM log_entries
    WHERE user_id = p_user_id
      AND habits IS NOT NULL
      AND array_length(habits, 1) > 0
    ORDER BY date DESC
  LOOP
    -- First iteration: record last log date
    IF v_last_log_date IS NULL THEN
      v_last_log_date := rec.date;
      v_streak_count := 1;
      v_prev_date := rec.date;
      CONTINUE;
    END IF;

    -- Check if this date is consecutive to the previous one
    IF rec.date = v_prev_date - INTERVAL '1 day' THEN
      v_streak_count := v_streak_count + 1;
      v_prev_date := rec.date;
    ELSE
      -- Streak broken: record longest if applicable, reset
      IF v_current_streak = 0 THEN
        -- This was the current streak (started from most recent)
        v_current_streak := v_streak_count;
      END IF;
      
      IF v_streak_count > v_longest_streak THEN
        v_longest_streak := v_streak_count;
      END IF;
      
      -- Start a new streak from this date
      v_streak_count := 1;
      v_prev_date := rec.date;
    END IF;
  END LOOP;

  -- After loop: finalize current and longest streaks
  IF v_current_streak = 0 THEN
    v_current_streak := v_streak_count;
  END IF;
  
  IF v_streak_count > v_longest_streak THEN
    v_longest_streak := v_streak_count;
  END IF;

  -- Check if current streak is still active (logged today or yesterday)
  IF v_last_log_date IS NOT NULL AND 
     v_last_log_date < CURRENT_DATE - INTERVAL '1 day' THEN
    v_current_streak := 0;
  END IF;

  RETURN QUERY SELECT v_current_streak, v_longest_streak, v_last_log_date;
END;
$$ LANGUAGE plpgsql STABLE;

-- Add comment for documentation
COMMENT ON FUNCTION calculate_habit_streak IS 
  'Calculates habit logging streaks for a user. A day counts if at least one habit was logged.';
