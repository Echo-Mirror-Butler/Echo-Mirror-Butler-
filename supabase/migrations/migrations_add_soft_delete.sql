-- Issue #592: Add soft delete support to auth.users table
-- This migration adds the necessary columns and triggers to support graceful account deletion

-- Add soft delete tracking columns to auth.users
ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS soft_deleted_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

-- Add index for querying expired accounts efficiently
CREATE INDEX IF NOT EXISTS idx_users_soft_deleted_at
  ON auth.users(soft_deleted_at)
  WHERE soft_deleted_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_deleted_at
  ON auth.users(deleted_at)
  WHERE deleted_at IS NOT NULL AND soft_deleted_at IS NOT NULL;

-- Add hidden flag to profiles to immediately hide data
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS hidden BOOLEAN DEFAULT FALSE;

-- Create index for filtering hidden profiles
CREATE INDEX IF NOT EXISTS idx_profiles_hidden ON profiles(hidden)
  WHERE hidden = TRUE;

-- Add trigger to prevent login for soft-deleted accounts
-- This trigger fires on auth.users.updated event
-- Function to check if user is soft-deleted and prevent login
CREATE OR REPLACE FUNCTION check_soft_deleted_account()
RETURNS TRIGGER AS $$
BEGIN
  -- If user is soft-deleted, prevent login by setting auth.uid() to null
  IF NEW.soft_deleted_at IS NOT NULL THEN
    -- Raise exception to prevent login
    RAISE EXCEPTION 'Account has been deleted and is in recovery period';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger on auth.users before update
DROP TRIGGER IF EXISTS tr_check_soft_deleted ON auth.users;
CREATE TRIGGER tr_check_soft_deleted
  BEFORE UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION check_soft_deleted_account();

-- Add recovery tracking table (optional but useful)
CREATE TABLE IF NOT EXISTS account_deletion_recovery (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  deleted_at TIMESTAMP WITH TIME ZONE NOT NULL,
  grace_period_ends_at TIMESTAMP WITH TIME ZONE NOT NULL,
  recovered_at TIMESTAMP WITH TIME ZONE,
  recovery_method TEXT, -- 'login', 'recovery_link', 'support'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_deletion_recovery_user_id ON account_deletion_recovery(user_id);
CREATE INDEX IF NOT EXISTS idx_deletion_recovery_grace_period ON account_deletion_recovery(grace_period_ends_at)
  WHERE recovered_at IS NULL;

-- Setup CASCADE deletes for related tables
-- These ensure that when a user is hard-deleted, all related data is removed

-- Log entries
ALTER TABLE log_entries
DROP CONSTRAINT IF EXISTS log_entries_user_id_fkey,
ADD CONSTRAINT log_entries_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- Comments
ALTER TABLE comments
DROP CONSTRAINT IF EXISTS comments_user_id_fkey,
ADD CONSTRAINT comments_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- Transactions
ALTER TABLE transactions
DROP CONSTRAINT IF EXISTS transactions_sender_id_fkey,
ADD CONSTRAINT transactions_sender_id_fkey
  FOREIGN KEY (sender_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE transactions
DROP CONSTRAINT IF EXISTS transactions_recipient_id_fkey,
ADD CONSTRAINT transactions_recipient_id_fkey
  FOREIGN KEY (recipient_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- Follows
ALTER TABLE follows
DROP CONSTRAINT IF EXISTS follows_follower_id_fkey,
ADD CONSTRAINT follows_follower_id_fkey
  FOREIGN KEY (follower_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE follows
DROP CONSTRAINT IF EXISTS follows_followee_id_fkey,
ADD CONSTRAINT follows_followee_id_fkey
  FOREIGN KEY (followee_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- Profiles
ALTER TABLE profiles
DROP CONSTRAINT IF EXISTS profiles_id_fkey,
ADD CONSTRAINT profiles_id_fkey
  FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- Pins
ALTER TABLE pins
DROP CONSTRAINT IF EXISTS pins_user_id_fkey,
ADD CONSTRAINT pins_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- Insights (if exists)
ALTER TABLE insights
DROP CONSTRAINT IF EXISTS insights_user_id_fkey,
ADD CONSTRAINT insights_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- Emotions/moods (if exists)
ALTER TABLE emotions
DROP CONSTRAINT IF EXISTS emotions_user_id_fkey,
ADD CONSTRAINT emotions_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
