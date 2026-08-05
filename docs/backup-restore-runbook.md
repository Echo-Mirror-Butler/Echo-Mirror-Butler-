# Issue #649: Database Backup Verification & Restore Runbook

## Problem

It was unclear whether Supabase's automated backups had ever been test-restored. An untested backup is not a real recovery guarantee — this doc records the current backup configuration, gives a repeatable restore-drill procedure, and provides a runbook to follow during a real incident.

## Current Backup Configuration

Supabase-hosted backup settings (frequency, retention, point-in-time recovery) are managed entirely in the **Supabase Dashboard** (`Project Settings → Database → Backups`), not in this repository. `supabase/config.toml` only configures the local CLI/Docker stack and has no backup section — there is nothing to read from the repo about backup schedule or retention.

This repo also has no project ref, staging project, or production project name checked in anywhere (`supabase/README.md` only shows a generic `supabase link --project-ref <your-project-ref>` placeholder), and there is no CI/CD pipeline that deploys migrations to a hosted project — `.github/workflows/ci.yml` only runs `supabase start` / `supabase test db` against an ephemeral local instance. Migrations are pushed manually via `supabase db push` per `supabase/README.md`.

**Action for the project owner:** fill in the table below from the Dashboard for whichever hosted project(s) exist (fields depend on plan tier — Free tier has no automated backups; Pro and above include daily backups with point-in-time recovery available on higher tiers).

| Field | Value |
|---|---|
| Project ref | _fill in_ |
| Plan tier | _fill in_ |
| Backup frequency | _fill in (Dashboard → Database → Backups)_ |
| Retention window | _fill in_ |
| Point-in-time recovery (PITR) enabled | _fill in_ |

### Other operational state a restore must account for

- Several migrations register `pg_cron` jobs (`send-weekly-digest`, `send-daily-reminder`, the 2 AM UTC hard-delete purge job). Scheduled jobs are **not** part of a database backup/restore in the same way as table data on some Supabase plans — verify they still exist and are scheduled after any restore (`select * from cron.job;`).
- Storage buckets (`avatars`, `log-images`, `stories`, `videos`, `images`, etc.) and their objects are backed up separately from the Postgres database on Supabase. Confirm storage objects, not just rows referencing them, come back after a restore.
- Edge Functions (`supabase/functions/*`) are deployed independently of the database and are unaffected by a database restore, but any function that depends on a table/row that didn't come back (e.g. `create-stellar-wallet`'s webhook target) should be re-verified.

## Restore Drill Procedure

Run this against a **disposable staging project**, never against production.

1. **Create a scratch Supabase project** in the Dashboard (free tier is fine for structure/data-integrity checks).
2. **Restore into it**, using whichever method matches the source project's plan:
   - If PITR/automated backups are enabled on the source project: use Dashboard → Database → Backups → Restore, targeting the scratch project (or follow Supabase's cross-project restore docs for your plan).
   - If no automated backups exist (e.g. Free tier): treat the migration history itself as the recovery mechanism — this drill instead validates that `supabase/migrations/*.sql` can rebuild the schema from empty, which is what fixing the "no backups" gap in the future will end up depending on regardless.
3. **Link and apply migrations to the scratch project:**
   ```bash
   supabase link --project-ref <scratch-project-ref>
   supabase db push
   ```
4. **Verify data integrity:**
   ```sql
   -- Row counts on the tables listed in supabase/README.md's troubleshooting section
   select 'log_entries', count(*) from public.log_entries
   union all select 'profiles', count(*) from public.profiles
   union all select 'mood_comment_notifications', count(*) from public.mood_comment_notifications
   union all select 'user_wallets', count(*) from public.user_wallets
   union all select 'gift_transactions', count(*) from public.gift_transactions;

   -- Spot-check a known row (adjust to a real id from the source project)
   select * from public.log_entries where id = '<known-id>';

   -- Cron jobs re-registered
   select jobname, schedule, active from cron.job;
   ```
5. **Verify RLS still enforces access control** — confirm `select * from pg_policies where schemaname = 'public';` returns the expected policies (row-level security is defined in migrations, so it comes back automatically via `db push`, but confirm it wasn't skipped).
6. **Record the result** (date run, who ran it, source project, scratch project, pass/fail, any gaps found) at the bottom of this doc or in the team's incident-tracking tool, and tear down the scratch project.

**Status:** this runbook has not yet been executed against a live project — no hosted project ref/credentials were available to run it end-to-end while writing this doc. The next maintainer with Dashboard access to the production project should run the drill above and record the result in the table below.

| Date | Run by | Source project | Result | Notes |
|---|---|---|---|---|
| _pending_ | _pending_ | _pending_ | _pending_ | First drill not yet run — see Status above |

## Real Recovery Runbook

Follow this during an actual incident (data loss, corruption, or a bad migration in production).

1. **Stop the bleeding first.** If a bad migration or query is actively corrupting data, pause writes if possible (e.g. rotate the app's `SUPABASE_ANON_KEY`/service key, or put the app in maintenance mode using the flag from issue #652) before starting recovery.
2. **Identify the target recovery point** — the latest known-good timestamp or backup, based on when the incident started.
3. **Restore via Dashboard → Database → Backups** to either the same project (in-place restore, if the plan supports it) or a fresh project you'll cut over to. Restoring into a fresh project first and validating before cutover is safer when time allows.
4. **Re-apply any migrations newer than the restored backup:**
   ```bash
   supabase link --project-ref <project-ref>
   supabase db push
   ```
5. **Re-verify cron jobs, storage buckets, and Edge Function secrets** as in step 4 of the drill above — these do not always travel with a database-only restore.
6. **Smoke test the app** against the restored project (login, create a log entry, check leaderboard/wallet reads) before pointing production traffic at it.
7. **Turn off maintenance mode** (issue #652 banner) once verified.
8. **Write a postmortem**: what was lost (if anything, by timestamp), root cause, and any gap this incident revealed in the drill procedure above — feed corrections back into this doc.

## Related Issues

- #652 — maintenance-mode banner, useful as step 1 of the real-recovery runbook above.
