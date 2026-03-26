# Supabase Local Development

This folder contains the database migrations, seed data, and Edge Functions used by the app.

## Prerequisites

- [Supabase CLI](https://supabase.com/docs/guides/cli/getting-started)
- A running local Supabase stack when you want to serve or test functions end to end

## Environment

Copy the example secrets file and set your values:

```bash
cp supabase/.env.example supabase/.env
supabase secrets set --env-file supabase/.env
```

## New User Wallet Function

The `create-stellar-wallet` Edge Function creates a Stellar wallet when a new auth user is inserted.

Location:

```text
supabase/functions/create-stellar-wallet/index.ts
```

Behavior:

- Generates a new Stellar keypair
- Funds it with Friendbot on testnet
- Skips Friendbot on mainnet
- Establishes an ECHO trustline
- Encrypts the secret key with `WALLET_ENCRYPTION_KEY`
- Inserts the wallet into `public.user_wallets` using the service role client

## Local Testing

Serve the function locally with:

```bash
supabase functions serve create-stellar-wallet --env-file supabase/.env --no-verify-jwt
```

The webhook payload should come from a Supabase Database Webhook on `auth.users` with the `INSERT` event.

## Webhook Setup

Configure a Database Webhook in the Supabase Dashboard:

1. Table: `auth.users`
2. Event: `INSERT`
3. Method: `POST`
4. URL: `{SUPABASE_URL}/functions/v1/create-stellar-wallet`

## Migrations and Seed

Apply the local schema and sample data with:

```bash
supabase db reset
```

This repo includes a seed row for one wallet and two gift transactions so the gift flow can be tested locally.
