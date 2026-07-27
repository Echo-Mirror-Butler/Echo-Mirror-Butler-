-- Migration: Content moderation — length limits, profanity filter, report flow
-- Issue #587
--
-- 1. CHECK constraints enforcing max length on mood_pin_comments.text and log_entries.notes
-- 2. Profanity filter trigger on mood_pin_comments (blocklist table)
-- 3. Extend reported_content to support more content types (notes, pins)
-- 4. Helper function to check if a user is blocked

-- ── 1. Length limits via CHECK constraints ─────────────────────────────────────

ALTER TABLE public.mood_pin_comments
  ADD CONSTRAINT mood_pin_comments_text_length
  CHECK (char_length(text) BETWEEN 1 AND 500);

ALTER TABLE public.log_entries
  ADD CONSTRAINT log_entries_notes_length
  CHECK (notes IS NULL OR char_length(notes) <= 2000);

-- ── 2. Profanity blocklist table ──────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.content_blocklist (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  word text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.content_blocklist ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  CREATE POLICY "Service role manages blocklist"
    ON public.content_blocklist FOR ALL
    USING (true)
    WITH CHECK (true);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Seed with common profanity (v1 — a small curated list)
INSERT INTO public.content_blocklist (word) VALUES
  ('damn'), ('hell'), ('ass'), ('shit'), ('fuck'),
  ('bitch'), ('crap'), ('bastard'), ('dick'),
  ('slut'), ('whore'), ('retard')
ON CONFLICT (word) DO NOTHING;

-- ── 3. Profanity filter trigger ───────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.enforce_profanity_filter()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_normalized text;
  v_blocked_word text;
BEGIN
  -- Normalize: lowercase, strip punctuation for matching
  v_normalized := regexp_replace(lower(NEW.text), '[^a-z0-9\s]', '', 'g');

  -- Check each word in the comment against the blocklist
  FOR v_blocked_word IN
    SELECT word FROM public.content_blocklist
  LOOP
    -- Word-boundary match to avoid false positives (e.g. "class" matching "ass")
    IF v_normalized ~ ('\m' || v_blocked_word || '\M') THEN
      RAISE EXCEPTION 'Comment contains inappropriate language'
        USING hint = 'Please revise your comment and try again',
              detail = 'Profanity filter triggered on blocked word';
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_profanity_filter ON public.mood_pin_comments;

CREATE TRIGGER trg_enforce_profanity_filter
  BEFORE INSERT ON public.mood_pin_comments
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_profanity_filter();

-- ── 4. Extend reported_content content_type ───────────────────────────────────
-- The table was created in 20260725000000_add_admin_moderation.sql with
-- CHECK (content_type IN ('mood_pin_comment')). We need to add more types.

ALTER TABLE public.reported_content
  DROP CONSTRAINT IF EXISTS reported_content_content_type_check;

ALTER TABLE public.reported_content
  ADD CONSTRAINT reported_content_content_type_check
  CHECK (content_type IN ('mood_pin_comment', 'mood_log_note', 'mood_pin'));

-- ── 5. Is-blocked helper function ─────────────────────────────────────────────
-- Returns true if blocker_id has blocked blocked_id.
-- Used by client queries to filter blocked users' content.

CREATE OR REPLACE FUNCTION public.is_user_blocked(p_blocker_id uuid, p_blocked_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_blocks
    WHERE blocker_id = p_blocker_id
      AND blocked_id = p_blocked_id
  );
$$;
