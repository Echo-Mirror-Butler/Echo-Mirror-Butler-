-- Migration: Create gift_transactions table
-- Created: 2024-02-24
-- Description: Creates the gift_transactions table for storing ECHO token transfers

CREATE TABLE IF NOT EXISTS gift_transactions (
    id SERIAL PRIMARY KEY,
    senderUserId INTEGER NOT NULL,
    recipientUserId INTEGER NOT NULL,
    echoAmount DOUBLE PRECISION NOT NULL,
    stellarTxHash VARCHAR(64),
    message VARCHAR(500),
    createdAt TIMESTAMP NOT NULL DEFAULT NOW(),
    status VARCHAR(20) NOT NULL DEFAULT 'pending'
);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS gift_transactions_sender_idx ON gift_transactions(senderUserId);
CREATE INDEX IF NOT EXISTS gift_transactions_recipient_idx ON gift_transactions(recipientUserId);
CREATE INDEX IF NOT EXISTS gift_transactions_created_idx ON gift_transactions(createdAt);

-- Add foreign key constraints if users table exists
-- ALTER TABLE gift_transactions ADD CONSTRAINT fk_gift_sender 
--     FOREIGN KEY (senderUserId) REFERENCES users(id) ON DELETE CASCADE;
-- ALTER TABLE gift_transactions ADD CONSTRAINT fk_gift_recipient 
--     FOREIGN KEY (recipientUserId) REFERENCES users(id) ON DELETE CASCADE;
