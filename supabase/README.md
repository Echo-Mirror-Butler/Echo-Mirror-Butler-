# Supabase Local Development

This project uses Supabase for backend services (auth, database, storage, realtime, edge functions). Contributors do **not** need access to the production Supabase project — everything runs locally via Docker.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (must be running)
- [Supabase CLI](https://supabase.com/docs/guides/cli/getting-started)

Install the CLI:
```bash
# macOS
brew install supabase/tap/supabase

# npm
npm install -g supabase
```

## Getting Started

```bash
# 1. Start local Supabase (Postgres, Auth, Storage, Realtime, Studio)
supabase start

# 2. This will print local credentials — copy the API URL and anon key
#    Default: http://127.0.0.1:54321 (API) and a local anon key

# 3. Run the Flutter app
flutter run
```

## Local Services

After `supabase start`, these are available:

| Service | URL |
|---|---|
| API | http://127.0.0.1:54321 |
| Studio (DB GUI) | http://127.0.0.1:54323 |
| Inbucket (email testing) | http://127.0.0.1:54324 |
| Database | postgresql://postgres:postgres@127.0.0.1:54322/postgres |

## Working with Migrations

```bash
# Apply migrations after pulling new changes
supabase db reset

# Create a new migration
supabase migration new my_migration_name

# Check diff between local and migration files
supabase db diff
```

## Access Model

The Supabase schema uses Row Level Security on every application table.

- `log_entries`, `stories`, and `mood_comment_notifications` are owner-scoped by `user_id`.
- `video_sessions` and `scheduled_sessions` are owner-scoped by `host_id`.
- `mood_pins` and `video_posts` are publicly readable feeds.
- `mood_pin_comments` are publicly readable, but inserts require an authenticated user whose `user_id` matches `auth.uid()`.

For a clean local verification run, start Supabase first and then reset the database:

```bash
supabase start
supabase db reset
```

## Stopping

```bash
supabase stop
```

## Edge Functions (optional)

Edge Functions require secrets for AI and video features. These are optional — the app works without them:

```bash
# Copy the example env
cp supabase/.env.example supabase/.env

# Set secrets for local dev
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

Local testing:

```bash
supabase functions serve create-stellar-wallet --env-file supabase/.env --no-verify-jwt
```

Database webhook:

1. Table: `auth.users`
2. Event: `INSERT`
3. Method: `POST`
4. URL: `{SUPABASE_URL}/functions/v1/create-stellar-wallet`

The webhook should point to the function endpoint in the Supabase Dashboard. Use `supabase/.env.example` as the template for the new secrets required by this function.
