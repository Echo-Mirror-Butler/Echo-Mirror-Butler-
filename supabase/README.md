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
