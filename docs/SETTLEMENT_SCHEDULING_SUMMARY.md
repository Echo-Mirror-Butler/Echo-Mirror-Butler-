# Settlement Scheduling Implementation Summary

## Issue Resolved
The `settle-leaderboard-rewards` Edge Function was fully implemented but never actually ran in production. Users saw leaderboard rankings and `echo_earned_this_week` values implying real stakes, but weekly top-earner payouts never executed automatically.

**Root cause:** No migration existed to schedule the function via `pg_cron`, unlike the established pattern used for `send-daily-reminder` and `send-weekly-digest`.

## Changes Made

### 1. New Migration: `supabase/migrations/20260829000001_schedule_settle_leaderboard_rewards.sql`

**Purpose:** Schedules `settle-leaderboard-rewards` to run automatically every Monday at 01:00 UTC via `pg_cron`.

**Key features:**
- Follows the exact pattern established by `20260726000003_schedule_daily_reminder_push.sql`
- Idempotent: checks if the job already exists before scheduling
- Uses `app.settings.supabase_url` and `app.settings.service_role_key` (must be configured in database)
- Runs every Monday at 01:00 UTC: `'0 1 * * 1'` (cron syntax)
- Timing ensures the week boundary (Monday 00:00 UTC) has passed before paying out

**Leaderboard & Settlement Alignment:**
- `leaderboard_weekly` view calculates earnings from `date_trunc('week', now())` (Monday 00:00 UTC)
- `settle-leaderboard-rewards` calculates week start via `getSettlementWeekStart()` (same logic)
- Settlement runs Monday at 01:00 UTC, after the weekly boundary crosses
- Payouts are recorded with reason `leaderboard_bonus_rank_{N}_week_{YYYY-MM-DD}` for idempotency

**Payout tiers:**
- Rank 1: 100 ECHO
- Rank 2: 75 ECHO
- Rank 3: 50 ECHO
- Ranks 4-10: 25 ECHO each

### 2. Testing Documentation: `docs/SETTLE_LEADERBOARD_REWARDS_TESTING.md`

Comprehensive guide for end-to-end verification including:
- How to apply the migration locally
- How to verify the cron job was created
- How to set up test data for the leaderboard
- How to manually trigger settlement for testing (without waiting until Monday)
- How to verify idempotency (no double-pays)
- How to verify week boundary behavior
- Troubleshooting guide
- Production deployment checklist

## Dependency on Issue #692

This implementation **assumes** that issue #692's idempotency and reliability fixes are in place (or will land) to prevent:
- Double-pays on transaction retry
- Silent ledger record loss
- Hardcoded testnet references

The migration adds a **recurring trigger** to the settlement function, which makes reliability more critical. The unique constraint from migration `20260828000000_add_leaderboard_reward_idempotency.sql` provides basic protection but issue #692 should address the underlying transaction and ledger safety issues.

## Acceptance Criteria Met

✅ `settle-leaderboard-rewards` now runs on a real weekly schedule (every Monday 01:00 UTC)
✅ Schedule follows the exact pattern of existing `pg_cron` migrations  
✅ Timing aligned with leaderboard's "this week" boundary definition (Monday UTC)
✅ Migration is idempotent and can be applied safely
✅ Comprehensive E2E testing documentation provided
✅ Ready for production deployment once issue #692 is resolved

## How to Deploy

### Local Testing
```bash
supabase db reset
# Runs all migrations including the new settlement scheduler
```

### Production Deployment
```bash
# 1. Ensure production Supabase has these configured:
#    - app.settings.supabase_url
#    - app.settings.service_role_key
#    - STELLAR_* environment variables in edge function config

# 2. Apply migration
supabase migration up --linked

# 3. Verify cron job exists
SELECT jobname FROM cron.job WHERE jobname = 'settle-leaderboard-rewards';

# 4. Monitor next Monday at 01:00 UTC for execution
# Check Supabase Dashboard → Functions → settle-leaderboard-rewards logs
```

## Files Modified
- ✅ Created: `supabase/migrations/20260829000001_schedule_settle_leaderboard_rewards.sql`
- ✅ Created: `docs/SETTLE_LEADERBOARD_REWARDS_TESTING.md`

## Related Issues/PRs
- Related to: #692 (idempotency and reliability fixes)
- Depends on: #692 (should land first or concurrently)
- Addresses: Weekly top-earner ECHO payouts now actually fire in production
