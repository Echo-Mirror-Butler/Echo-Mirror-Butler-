BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "user_wallets" (
    "id" bigserial PRIMARY KEY,
    "userId" bigint NOT NULL,
    "echoBalance" double precision NOT NULL DEFAULT 0,
    "stellarPublicKey" text,
    "createdAt" timestamp without time zone NOT NULL DEFAULT NOW(),
    "updatedAt" timestamp without time zone NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX "user_wallet_user_idx" ON "user_wallets" USING btree ("userId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "gift_transactions" (
    "id" bigserial PRIMARY KEY,
    "senderUserId" bigint NOT NULL,
    "recipientUserId" bigint NOT NULL,
    "echoAmount" double precision NOT NULL,
    "stellarTxHash" text,
    "message" text,
    "createdAt" timestamp without time zone NOT NULL DEFAULT NOW(),
    "status" text NOT NULL DEFAULT 'pending'
);

CREATE INDEX "gift_tx_sender_idx" ON "gift_transactions" USING btree ("senderUserId");
CREATE INDEX "gift_tx_recipient_idx" ON "gift_transactions" USING btree ("recipientUserId");

COMMIT;
