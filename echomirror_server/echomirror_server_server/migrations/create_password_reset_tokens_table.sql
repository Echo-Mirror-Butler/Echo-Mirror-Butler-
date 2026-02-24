-- Migration: Create password_reset_tokens table
-- This table stores password reset tokens for users
-- Run this SQL manually or include it in your next Serverpod migration

CREATE TABLE IF NOT EXISTS "password_reset_tokens" (
    "id" SERIAL PRIMARY KEY,
    "email" VARCHAR(255) NOT NULL,
    "token" VARCHAR(255) NOT NULL UNIQUE,
    "expires_at" TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    "created_at" TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index for faster lookups by email
CREATE INDEX IF NOT EXISTS "password_reset_tokens_email_idx" 
    ON "password_reset_tokens" USING btree ("email");

-- Index for faster lookups by token
CREATE INDEX IF NOT EXISTS "password_reset_tokens_token_idx" 
    ON "password_reset_tokens" USING btree ("token");

-- Index for cleaning up expired tokens
CREATE INDEX IF NOT EXISTS "password_reset_tokens_expires_at_idx" 
    ON "password_reset_tokens" USING btree ("expires_at");

-- Optional: Add a constraint to ensure tokens expire
-- You can also add a cleanup job to delete expired tokens periodically

