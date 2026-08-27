-- Migration to add balance and updated_at columns to user_wallets
-- This fixes the schema mismatch with the reward trigger function

ALTER TABLE public.user_wallets 
-- Added balance with DEFAULT 0.0. Change to 10.0 if a welcome bonus is desired.
ADD COLUMN IF NOT EXISTS balance float8 NOT NULL DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
