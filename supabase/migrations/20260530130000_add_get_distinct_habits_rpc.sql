-- Migration: Add RPC to fetch distinct habit values for autocomplete
-- Issue #393: habit filter with autocomplete on logs list page

CREATE OR REPLACE FUNCTION public.get_distinct_habits(p_user_id uuid)
RETURNS text[]
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_habits text[];
BEGIN
    SELECT ARRAY(
        SELECT DISTINCT jsonb_array_elements_text(habits) AS habit
        FROM public.log_entries
        WHERE user_id = p_user_id
          AND habits IS NOT NULL
          AND jsonb_array_length(habits) > 0
        ORDER BY habit
    ) INTO v_habits;

    RETURN COALESCE(v_habits, ARRAY[]::text[]);
END;
$$;