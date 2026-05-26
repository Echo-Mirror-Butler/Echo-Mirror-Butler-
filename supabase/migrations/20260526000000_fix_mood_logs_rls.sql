-- Drop all existing policies on mood_logs to avoid conflicts
DO $$
DECLARE
    pol record;
BEGIN
    FOR pol IN
        SELECT policyname
        FROM pg_policies
        WHERE tablename = 'mood_logs'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON mood_logs', pol.policyname);
    END LOOP;
END
$$;

-- Ensure RLS is enabled
ALTER TABLE mood_logs ENABLE ROW LEVEL SECURITY;

-- Create correct policies
CREATE POLICY "Users can view own mood logs"
ON mood_logs FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own mood logs"
ON mood_logs FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own mood logs"
ON mood_logs FOR UPDATE
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own mood logs"
ON mood_logs FOR DELETE
TO authenticated
USING (auth.uid() = user_id);
