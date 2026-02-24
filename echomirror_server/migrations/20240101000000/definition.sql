-- EchoMirror Server Database Schema

-- Echo Wallets table
CREATE TABLE IF NOT EXISTS echo_wallets (
    id SERIAL PRIMARY KEY,
    "userId" INTEGER NOT NULL UNIQUE,
    balance DOUBLE PRECISION NOT NULL DEFAULT 10.0,
    "createdAt" TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS echo_wallet_user_idx ON echo_wallets ("userId");

-- Gift Transactions table
CREATE TABLE IF NOT EXISTS gift_transactions (
    id SERIAL PRIMARY KEY,
    "senderUserId" INTEGER NOT NULL,
    "recipientUserId" INTEGER NOT NULL,
    "echoAmount" DOUBLE PRECISION NOT NULL,
    "createdAt" TIMESTAMP NOT NULL DEFAULT NOW(),
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    "stellarTxHash" VARCHAR(255),
    message TEXT
);

CREATE INDEX IF NOT EXISTS gift_tx_sender_idx ON gift_transactions ("senderUserId");
CREATE INDEX IF NOT EXISTS gift_tx_recipient_idx ON gift_transactions ("recipientUserId");

-- Mood Pins table
CREATE TABLE IF NOT EXISTS mood_pins (
    id SERIAL PRIMARY KEY,
    sentiment VARCHAR(50) NOT NULL,
    "gridLat" DOUBLE PRECISION NOT NULL,
    "gridLon" DOUBLE PRECISION NOT NULL,
    timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
    "expiresAt" TIMESTAMP NOT NULL,
    "userId" INTEGER
);

CREATE INDEX IF NOT EXISTS mood_pin_expires_idx ON mood_pins ("expiresAt");
CREATE INDEX IF NOT EXISTS mood_pin_user_idx ON mood_pins ("userId");

-- Video Posts table
CREATE TABLE IF NOT EXISTS video_posts (
    id SERIAL PRIMARY KEY,
    "videoUrl" TEXT NOT NULL,
    "moodTag" VARCHAR(100) NOT NULL,
    timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
    "expiresAt" TIMESTAMP NOT NULL,
    "userId" INTEGER
);

CREATE INDEX IF NOT EXISTS video_post_expires_idx ON video_posts ("expiresAt");
CREATE INDEX IF NOT EXISTS video_post_user_idx ON video_posts ("userId");

-- Mood Pin Comments table
CREATE TABLE IF NOT EXISTS mood_pin_comments (
    id SERIAL PRIMARY KEY,
    "moodPinId" INTEGER NOT NULL REFERENCES mood_pins(id) ON DELETE CASCADE,
    text TEXT NOT NULL,
    timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
    "userId" INTEGER
);

CREATE INDEX IF NOT EXISTS comment_pin_idx ON mood_pin_comments ("moodPinId");
CREATE INDEX IF NOT EXISTS comment_user_idx ON mood_pin_comments ("userId");
