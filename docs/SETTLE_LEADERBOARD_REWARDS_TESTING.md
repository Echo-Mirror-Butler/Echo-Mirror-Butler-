# End-to-End Testing Guide: settle-leaderboard-rewards Scheduling

## Overview
The migration `20260829000001_schedule_settle_leaderboard_rewards.sql` schedules the `settle-leaderboard-rewards` Edge Function to run every Monday at 01:00 UTC via `pg_cron`.

## Prerequisites
- Local Supabase running: `supabase start`
- Service role key and API URL configured as custom database settings
- Test data: users with stellar wallets and echo_rewards in the current week

## Step 1: Apply the Migration Locally

```bash
cd /workspaces/Echo-Mirror-Butler-

# Apply migrations to local Supabase (includes the new settlement scheduling)
supabase db reset
```

## Step 2: Verify the Cron Job Was Created

Connect to the local Supabase database and check that the job exists:

```bash
# Option A: Via psql
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
  -c "SELECT jobname, schedule, command FROM cron.job WHERE jobname = 'settle-leaderboard-rewards';"

# Expected output:
#           jobname          |   schedule   |                                                                  command
# ---------------------------+--------------+------------------------------------------------------------------------------------------------------------
#  settle-leaderboard-rewards | 0 1 * * 1   | select net.http_post(url := current_setting(...) ...

# Option B: Via Supabase Studio SQL Editor
# Go to http://127.0.0.1:54323 → SQL Editor and run:
SELECT jobname, schedule, command FROM cron.job WHERE jobname = 'settle-leaderboard-rewards';
```

**Expected result:** One row showing the job scheduled for Mondays at 01:00 UTC (`0 1 * * 1`).

## Step 3: Set Up Test Data

Before testing settlement, create test leaderboard data:

```sql
-- Create test users with wallets (run in Supabase Studio)
INSERT INTO public.profiles (id, display_name, leaderboard_anonymous)
VALUES 
  ('user-1', 'Rank 1 Earner', false),
  ('user-2', 'Rank 2 Earner', false),
  ('user-3', 'Rank 3 Earner', false)
ON CONFLICT DO NOTHING;

-- Add stellar wallets for each user
-- (Use valid testnet public keys or generate via Friendbot)
INSERT INTO public.stellar_wallets (user_id, public_key, created_at)
VALUES 
  ('user-1', 'GBWQZ4BTDGN5KNPXF7OPBPZF4KEGLYJ5ETUGQHBXXR6M6TTNXFBAKDXF', NOW()),
  ('user-2', 'GBRPYHIL2CI3WHZDTOOQFC6EB4RBWDUVM6FSJ7S7BTWY73JZCRKLHX4T', NOW()),
  ('user-3', 'GCZST3XVCDTUJ76ZAV2HA72KYIWXHUGOM2ZRHYWM6RCXVL7GCVJ5RRQL', NOW())
ON CONFLICT DO NOTHING;

-- Add echo_rewards for this week (to build up the leaderboard)
-- The leaderboard view calculates earnings from date_trunc('week', now())
INSERT INTO public.echo_rewards (user_id, reason, amount, created_at)
VALUES 
  ('user-1', 'mood_log_streak_day_1', 50, NOW()),
  ('user-1', 'mood_log_streak_day_2', 50, NOW()),
  ('user-2', 'mood_log_streak_day_1', 40, NOW()),
  ('user-2', 'mood_log_streak_day_2', 35, NOW()),
  ('user-3', 'mood_log_streak_day_1', 30, NOW()),
  ('user-3', 'mood_log_streak_day_2', 20, NOW());
```

## Step 4: Verify Leaderboard View Reflects Test Data

```sql
-- Check that leaderboard_weekly view shows the test users
SELECT id, rank, echo_earned_this_week, display_name 
FROM public.leaderboard_weekly 
WHERE id IN ('user-1', 'user-2', 'user-3')
ORDER BY rank;

-- Expected output (approximately):
--      id    | rank | echo_earned_this_week |    display_name
-- -----------+------+-----------------------+--------------------
#  user-1    |    1 |                   100 | Rank 1 Earner
#  user-2    |    2 |                    75 | Rank 2 Earner
#  user-3    |    3 |                    50 | Rank 3 Earner
```

## Step 5: Set Database Configuration for Cron Execution

The cron job uses `current_setting('app.settings.supabase_url')` and `current_setting('app.settings.service_role_key')`. Set these in the database:

```sql
-- Get values from supabase start output
-- API URL is typically: http://127.0.0.1:54321
-- Service role key is in the output

-- Set database config
ALTER DATABASE postgres SET app.settings.supabase_url = 'http://127.0.0.1:54321';
ALTER DATABASE postgres SET app.settings.service_role_key = '<your-service-role-key>';

-- Verify they were set
SHOW app.settings.supabase_url;
SHOW app.settings.service_role_key;
```

## Step 6: Manually Trigger Settlement (Test Execution)

Since we can't wait until Monday, manually invoke the function to test it:

```bash
# Get the service role key from supabase start output
SERVICE_ROLE_KEY="<your-service-role-key>"

# Call the function
curl -X POST http://127.0.0.1:54321/functions/v1/settle-leaderboard-rewards \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json"

# Expected response (success):
# {
#   "success": true,
#   "settledAt": "2026-08-29T12:34:56.789Z",
#   "totalPayouts": 3,
#   "results": [
#     {
#       "rank": 1,
#       "userId": "user-1",
#       "amount": 100,
#       "txHash": "...",
#       "success": true
#     },
#     ...
#   ]
# }
```

## Step 7: Verify Payouts Were Recorded

Check that payouts appear in the `echo_rewards` table with the settlement reason:

```sql
-- Look for settlement payouts
SELECT user_id, reason, amount, stellar_tx_hash, created_at
FROM public.echo_rewards
WHERE reason LIKE 'leaderboard_bonus_rank_%'
ORDER BY created_at DESC, rank;

-- Expected output:
--  user_id |         reason          | amount | stellar_tx_hash | created_at
-- ---------+-------------------------+--------+-----------------+--------------------
#  user-1  | leaderboard_bonus_rank_1_week_2026-08-29 |    100 | <tx-hash> | 2026-08-29 12:34:56
#  user-2  | leaderboard_bonus_rank_2_week_2026-08-29 |     75 | <tx-hash> | 2026-08-29 12:34:56
#  user-3  | leaderboard_bonus_rank_3_week_2026-08-29 |     50 | <tx-hash> | 2026-08-29 12:34:56
```

## Step 8: Verify Idempotency

Re-run the settlement function — it should skip already-paid users:

```bash
# Call the function again
curl -X POST http://127.0.0.1:54321/functions/v1/settle-leaderboard-rewards \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json"

# Expected response:
# {
#   "success": true,
#   "totalPayouts": 0,  # <-- No new payouts
#   "results": []
# }
```

Check the database — no duplicate entries should exist:

```sql
-- Count settlement payouts per user
SELECT user_id, COUNT(*) as payout_count
FROM public.echo_rewards
WHERE reason LIKE 'leaderboard_bonus_rank_%'
GROUP BY user_id;

-- Expected output (all counts should be 1, no duplicates):
#  user_id | payout_count
# ---------+--------------
#  user-1  |            1
#  user-2  |            1
#  user-3  |            1
```

## Step 9: Verify Week Boundary Reset Behavior

To test that the leaderboard properly resets after a new week starts, simulate the next Monday:

```sql
-- Advance the leaderboard clock by inserting rewards with future dates
-- (In production, this would happen naturally over time)

-- Simulate payouts from a PREVIOUS week (older than current week boundary)
INSERT INTO public.echo_rewards (user_id, reason, amount, created_at)
VALUES 
  ('user-1', 'mood_log_streak_day_1', 25, NOW() - INTERVAL '8 days');

-- View the leaderboard — it should NOT include the old reward
-- (because leaderboard_weekly filters: er.created_at >= date_trunc('week', now()))
SELECT id, rank, echo_earned_this_week FROM public.leaderboard_weekly 
WHERE id = 'user-1';

-- After running settlement again on a new Monday, user-1 should not receive
-- a duplicate payout for the old week (idempotency guard by reason)
```

## Step 10: Verify Production Readiness

Before merging:

- [ ] Migration applies without errors: `supabase db reset` succeeds
- [ ] Cron job appears in `cron.job` table with correct schedule
- [ ] Manual settlement execution succeeds with valid payouts
- [ ] Idempotency prevents double-pays on retry
- [ ] Leaderboard view correctly reflects only current-week earnings
- [ ] Database settings (`app.settings.supabase_url`, `app.settings.service_role_key`) can be configured
- [ ] Edge Function has proper error handling and logging

## Troubleshooting

### "Failed to fetch leaderboard" error
- Ensure `leaderboard_entries` table exists (it's actually `leaderboard_weekly` view)
- Check that Stellar environment variables are set: `STELLAR_NETWORK`, `STELLAR_ISSUER_PUBLIC_KEY`, `STELLAR_ISSUER_SECRET_KEY`

### Cron job not firing
- Verify database settings are set: `SHOW app.settings.supabase_url;`
- Check Supabase logs for `pg_cron` execution logs
- Ensure the Edge Function endpoint is reachable from the database

### "Recipient account is not funded on Stellar mainnet"
- This is expected and handled — testnet uses Friendbot to fund accounts
- Ensure `STELLAR_NETWORK=testnet` is set

### Duplicate payouts
- Check that the unique index was created: 
  ```sql
  SELECT * FROM pg_indexes WHERE tablename = 'echo_rewards' AND indexname LIKE '%leaderboard%';
  ```
- Verify migration `20260828000000_add_leaderboard_reward_idempotency.sql` was applied

---

## Deployment Checklist

For production deployment:

1. **Pre-deployment:**
   - Run all steps 1-10 locally to verify functionality
   - Confirm issue #692 idempotency fixes are merged
   - Ensure Stellar keys and environment are production-ready

2. **Deployment:**
   - Apply migration to production Supabase project
   - Set `app.settings.supabase_url` and `app.settings.service_role_key` in production database
   - Monitor the first scheduled run (next Monday at 01:00 UTC)

3. **Post-deployment:**
   - Check Supabase logs for successful edge function invocations
   - Verify top-10 users receive payouts each Monday
   - Monitor for any errors in settlement and adjust schedule if needed

