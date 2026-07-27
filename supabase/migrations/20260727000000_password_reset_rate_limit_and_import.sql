-- Issues #633 / #636:
-- 1. Auth rate limits keyed by email/IP (password reset spam + enumeration)
-- 2. Bulk log import RPC that bypasses the per-hour mood_log rate limit for historical backfill

-- ── Auth rate limits (email / IP keys, no FK to auth.users) ─────────────────
CREATE TABLE IF NOT EXISTS public.auth_rate_limits (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    key text NOT NULL,
    action text NOT NULL,
    window_start timestamptz NOT NULL,
    count integer NOT NULL DEFAULT 1,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (key, action, window_start)
);

CREATE INDEX IF NOT EXISTS idx_auth_rate_limits_key_action_window
    ON public.auth_rate_limits (key, action, window_start);

ALTER TABLE public.auth_rate_limits ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    CREATE POLICY "Service role manages auth_rate_limits"
        ON public.auth_rate_limits FOR ALL
        USING (true)
        WITH CHECK (true);
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- Returns true if allowed (under limit), false if rate-limited.
CREATE OR REPLACE FUNCTION public.check_auth_rate_limit(
    p_key text,
    p_action text,
    p_max_count integer DEFAULT 3,
    p_window_minutes integer DEFAULT 60
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_window_start timestamptz;
    v_current_count integer;
    v_row_id uuid;
    v_minutes integer;
BEGIN
    IF p_key IS NULL OR length(trim(p_key)) = 0 THEN
        RETURN false;
    END IF;

    v_minutes := GREATEST(1, COALESCE(p_window_minutes, 60));
    -- Bucket into fixed windows of p_window_minutes
    v_window_start := to_timestamp(
        floor(extract(epoch FROM now()) / (v_minutes * 60)) * (v_minutes * 60)
    );

    SELECT id, count INTO v_row_id, v_current_count
    FROM public.auth_rate_limits
    WHERE key = p_key
      AND action = p_action
      AND window_start = v_window_start
    FOR UPDATE;

    IF NOT FOUND THEN
        INSERT INTO public.auth_rate_limits (key, action, window_start, count)
        VALUES (p_key, p_action, v_window_start, 1);
        RETURN true;
    END IF;

    IF v_current_count >= p_max_count THEN
        RETURN false;
    END IF;

    UPDATE public.auth_rate_limits
    SET count = count + 1
    WHERE id = v_row_id;

    RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.check_auth_rate_limit(text, text, integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_auth_rate_limit(text, text, integer, integer) TO service_role;

-- ── Mood log rate limit: allow bulk import via session GUC ──────────────────
CREATE OR REPLACE FUNCTION public.enforce_mood_log_rate_limit()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_allowed boolean;
    v_retry_after_seconds int;
    v_importing text;
BEGIN
    -- Bulk import RPC sets app.importing_logs = 'true' for historical backfill.
    v_importing := current_setting('app.importing_logs', true);
    IF v_importing = 'true' THEN
        RETURN NEW;
    END IF;

    v_allowed := public.check_rate_limit(NEW.user_id, 'mood_log', 10, 1.0);

    IF NOT v_allowed THEN
        v_retry_after_seconds := greatest(
            1,
            ceil(extract(epoch FROM (date_trunc('hour', now()) + interval '1 hour' - now())))::int
        );

        RAISE sqlstate 'PT429' USING
            message = json_build_object(
                'error', 'rate_limit_exceeded',
                'retry_after_seconds', v_retry_after_seconds
            )::text,
            detail = 'Maximum 10 mood log entries per user per hour exceeded',
            hint = format('Retry after %s seconds', v_retry_after_seconds);
    END IF;

    RETURN NEW;
END;
$$;

-- ── Bulk import log entries (authenticated user only, dedupe by date) ───────
CREATE OR REPLACE FUNCTION public.import_log_entries(p_rows jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_row jsonb;
    v_date_text text;
    v_date timestamptz;
    v_mood int;
    v_habits jsonb;
    v_notes text;
    v_existing_id uuid;
    v_inserted int := 0;
    v_skipped int := 0;
    v_errors jsonb := '[]'::jsonb;
    v_idx int := 0;
    v_err text;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'not_authenticated',
            'inserted', 0,
            'skipped', 0,
            'errors', '[]'::jsonb
        );
    END IF;

    IF p_rows IS NULL OR jsonb_typeof(p_rows) <> 'array' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'invalid_payload',
            'inserted', 0,
            'skipped', 0,
            'errors', jsonb_build_array(jsonb_build_object('row', 0, 'error', 'Expected a JSON array of rows'))
        );
    END IF;

    IF jsonb_array_length(p_rows) > 500 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'too_many_rows',
            'inserted', 0,
            'skipped', 0,
            'errors', jsonb_build_array(jsonb_build_object('row', 0, 'error', 'Maximum 500 rows per import'))
        );
    END IF;

    PERFORM set_config('app.importing_logs', 'true', true);

    FOR v_row IN SELECT * FROM jsonb_array_elements(p_rows)
    LOOP
        v_idx := v_idx + 1;
        v_err := NULL;

        BEGIN
            v_date_text := COALESCE(v_row->>'date', '');
            IF v_date_text = '' THEN
                v_err := 'Missing date';
            ELSE
                -- Accept YYYY-MM-DD or full ISO timestamps
                IF length(v_date_text) = 10 THEN
                    v_date := (v_date_text || 'T12:00:00.000Z')::timestamptz;
                ELSE
                    v_date := v_date_text::timestamptz;
                END IF;
            END IF;

            IF v_err IS NULL THEN
                IF v_row ? 'mood' AND v_row->>'mood' IS NOT NULL AND v_row->>'mood' <> '' THEN
                    v_mood := (v_row->>'mood')::int;
                    IF v_mood < 1 OR v_mood > 5 THEN
                        v_err := 'Mood must be between 1 and 5';
                    END IF;
                ELSE
                    v_mood := NULL;
                END IF;
            END IF;

            IF v_err IS NULL THEN
                IF jsonb_typeof(v_row->'habits') = 'array' THEN
                    v_habits := v_row->'habits';
                ELSIF v_row->>'habits' IS NOT NULL AND v_row->>'habits' <> '' THEN
                    v_habits := to_jsonb(
                        string_to_array(replace(v_row->>'habits', '; ', ';'), ';')
                    );
                ELSE
                    v_habits := '[]'::jsonb;
                END IF;

                v_notes := NULLIF(trim(COALESCE(v_row->>'notes', '')), '');
                IF v_notes IS NOT NULL AND char_length(v_notes) > 2000 THEN
                    v_err := 'Notes exceed 2000 characters';
                END IF;
            END IF;

            IF v_err IS NOT NULL THEN
                v_errors := v_errors || jsonb_build_array(
                    jsonb_build_object('row', v_idx, 'error', v_err)
                );
                CONTINUE;
            END IF;

            -- Dedup by calendar day for this user
            SELECT id INTO v_existing_id
            FROM public.log_entries
            WHERE user_id = v_user_id
              AND date::date = v_date::date
            LIMIT 1;

            IF v_existing_id IS NOT NULL THEN
                v_skipped := v_skipped + 1;
                CONTINUE;
            END IF;

            INSERT INTO public.log_entries (user_id, date, mood, habits, notes)
            VALUES (v_user_id, v_date, v_mood, v_habits, v_notes);

            v_inserted := v_inserted + 1;
        EXCEPTION
            WHEN OTHERS THEN
                v_errors := v_errors || jsonb_build_array(
                    jsonb_build_object('row', v_idx, 'error', SQLERRM)
                );
        END;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'inserted', v_inserted,
        'skipped', v_skipped,
        'errors', v_errors
    );
END;
$$;

REVOKE ALL ON FUNCTION public.import_log_entries(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.import_log_entries(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.import_log_entries(jsonb) TO service_role;
