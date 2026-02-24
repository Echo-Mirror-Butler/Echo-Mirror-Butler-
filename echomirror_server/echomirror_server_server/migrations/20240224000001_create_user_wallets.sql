-- Migration: Create user_wallets table
-- Created: 2024-02-24
-- Description: Creates the user_wallets table for storing user wallet information

CREATE TABLE IF NOT EXISTS user_wallets (
    id SERIAL PRIMARY KEY,
    userId INTEGER NOT NULL UNIQUE,
    echoBalance DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    stellarPublicKey VARCHAR(56),
    createdAt TIMESTAMP NOT NULL DEFAULT NOW(),
    updatedAt TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS user_wallets_user_id_idx ON user_wallets(userId);

-- Add trigger to automatically update updatedAt timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updatedAt = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_user_wallets_updated_at 
    BEFORE UPDATE ON user_wallets 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();
