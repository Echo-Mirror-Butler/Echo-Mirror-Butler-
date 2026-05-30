# create-stellar-wallet Edge Function

## Overview

This Supabase Edge Function creates a Stellar wallet for a user when they sign up. It is designed to be **idempotent** — calling it multiple times for the same user will not create duplicate wallets or throw errors.

## Behavior

### First Call

1. Generates a new Stellar keypair
2. Funds the account via Friendbot (testnet only)
3. Establishes a trustline to the ECHO asset
4. Encrypts and stores the secret key in `user_wallets`
5. Returns HTTP 201 with wallet details

### Subsequent Calls (Idempotent)

1. Checks if a wallet already exists for the `user_id`
2. If found, returns the existing wallet with HTTP 200
3. No duplicate wallet is created
4. No error is thrown

## Request

**Method:** `POST`

**Payload:**

```json
{
  "type": "INSERT",
  "schema": "auth",
  "table": "users",
  "record": {
    "id": "user-uuid-here"
  }
}
```

## Response

### Success (New Wallet)

**Status:** `201 Created`

```json
{
  "message": "Wallet created successfully",
  "alreadyExists": false,
  "walletId": "wallet-uuid",
  "publicKey": "GXXXXXXX...",
  "funded": true,
  "trustlineCreated": true
}
```

### Success (Existing Wallet)

**Status:** `200 OK`

```json
{
  "message": "Wallet already exists for this user",
  "alreadyExists": true,
  "walletId": "wallet-uuid",
  "publicKey": "GXXXXXXX...",
  "funded": false,
  "trustlineCreated": true
}
```

### Error

**Status:** `500 Internal Server Error`

```json
{
  "error": "Error message here"
}
```

## Environment Variables

- `STELLAR_NETWORK` — `testnet` or `mainnet` (default: `testnet`)
- `STELLAR_ISSUER_PUBLIC_KEY` — Public key of the ECHO asset issuer (required)
- `STELLAR_ASSET_CODE` — Asset code (default: `ECHO`)
- `WALLET_ENCRYPTION_KEY` — 32-byte encryption key for secret storage (required)
- `SUPABASE_URL` — Supabase project URL (auto-provided)
- `SUPABASE_SERVICE_ROLE_KEY` — Service role key (auto-provided)

## Testing

To test idempotent behavior:

```bash
# Call once
curl -X POST https://your-project.supabase.co/functions/v1/create-stellar-wallet \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"type":"INSERT","schema":"auth","table":"users","record":{"id":"test-user-id"}}'

# Call again with same user_id - should return existing wallet
curl -X POST https://your-project.supabase.co/functions/v1/create-stellar-wallet \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"type":"INSERT","schema":"auth","table":"users","record":{"id":"test-user-id"}}'
```

## Database Schema

The function interacts with the `user_wallets` table:

```sql
CREATE TABLE user_wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  public_key TEXT NOT NULL,
  encrypted_secret TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

The `UNIQUE` constraint on `user_id` ensures only one wallet per user at the database level.
