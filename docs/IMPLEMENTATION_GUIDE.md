# Echo-Mirror-Butler: Issues #592-595 Implementation Guide

Complete implementation package for 4 interconnected issues addressing compliance, reliability, and quality.

## Overview

| Issue | Title | Priority | Status | Files |
|-------|-------|----------|--------|-------|
| #592 | Account Deletion with Grace Period | HIGH | Complete | 4 files |
| #593 | AI Insight Generation Fix | HIGH | Complete | 1 file |
| #594 | Global Mirror Implementation Audit | MEDIUM | Complete | 1 file |
| #595 | Structured Logging & Tracing | HIGH | Complete | 1 file |

## Quick Start

### Prerequisites
- Supabase project with Edge Functions support
- Postgres with http extension enabled
- Flutter and web frontend environments

### Implementation Order

1. **Start with #595** (Foundation)
   - Copy `logger.ts` to `supabase/functions/_shared/`
   - Update all Edge Functions to use shared logger
   - This enables debugging for all other work

2. **Then #592** (Compliance - Urgent)
   - Run `migrations_add_soft_delete.sql` 
   - Deploy `delete-account-function.ts` as Edge Function
   - Deploy `export-user-data-improved.ts` as Edge Function
   - Deploy `hard-delete-scheduled-job.ts` with pg_cron schedule
   - Add UI buttons to web and Flutter settings

3. **Then #593** (UX Fix)
   - Apply insight trigger migration
   - Update Flutter AI insight section with error handling
   - Update `generate-insight` Edge Function with structured logging

4. **Then #594** (Polish)
   - Add comprehensive test coverage
   - Audit features against specification
   - Document findings

## File Structure

```
implementation-files/
├── logger.ts                          # Issue #595 - Shared logging utility
├── delete-account-function.ts         # Issue #592 - Soft delete handler
├── export-user-data-improved.ts       # Issue #592 - Data export endpoint
├── hard-delete-scheduled-job.ts       # Issue #592 - Scheduled hard delete
├── migrations_add_soft_delete.sql     # Issue #592 - Database schema
├── issue-593-ai-insight-fix.md        # Issue #593 - Insight generation
├── issue-594-global-mirror-audit.md   # Issue #594 - Map audit & tests
└── IMPLEMENTATION_GUIDE.md            # This file
```

## Detailed Implementation

### Issue #595: Structured Logging (Foundation)

**Why First**: Enables debugging for all other functions. Core to debugging the account deletion and insight generation flows.

**Files**: `logger.ts`

**Installation**:
```bash
# Copy to Supabase
cp logger.ts supabase/functions/_shared/

# Update all Edge Functions to import and use
import { createLogger, extractTraceId, addTraceIdToResponse } from './_shared/logger.ts';

const logger = createLogger('function-name');

// In handlers:
const traceId = logger.info('Operation started', { userId }, incomingTraceId);
// Return traceId in response headers for client correlation
```

**Verification**:
```bash
# Check Supabase function logs - should see structured JSON
# Example output:
# {"level":"info","functionName":"delete-account","requestId":"abc-123","timestamp":"2024-01-15T10:30:00Z","message":"Delete account request received","data":{"userId":"user-123"}}
```

### Issue #592: Account Deletion with Grace Period (Compliance)

**Why**: Legal requirement for data privacy. Enables self-service account deletion without manual support.

**Files**:
- `migrations_add_soft_delete.sql`
- `delete-account-function.ts`
- `export-user-data-improved.ts`
- `hard-delete-scheduled-job.ts`

**Setup Steps**:

1. **Database Migration**:
```bash
# Run in Supabase SQL editor or via migration tool
psql -U postgres -d postgres -f migrations_add_soft_delete.sql

# Verify
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'users' AND column_name LIKE '%deleted%';
# Should show: soft_deleted_at, deleted_at
```

2. **Deploy Edge Functions**:
```bash
# Create functions directory structure
mkdir -p supabase/functions/delete-account
mkdir -p supabase/functions/export-user-data
mkdir -p supabase/functions/hard-delete-accounts

# Copy files
cp delete-account-function.ts supabase/functions/delete-account/index.ts
cp export-user-data-improved.ts supabase/functions/export-user-data/index.ts
cp hard-delete-scheduled-job.ts supabase/functions/hard-delete-accounts/index.ts

# Deploy
supabase functions deploy delete-account
supabase functions deploy export-user-data
supabase functions deploy hard-delete-accounts
```

3. **Schedule Recurring Job**:
```sql
-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Create scheduled job for daily hard-deletes
SELECT cron.schedule(
  'hard-delete-expired-accounts',
  '0 2 * * *',  -- Daily at 2 AM
  $$
  SELECT net.http_post(
    'https://[YOUR_PROJECT].supabase.co/functions/v1/hard-delete-accounts',
    json_build_object('type', 'scheduled'),
    json_build_object(
      'Authorization', 'Bearer [SERVICE_ROLE_KEY]',
      'Content-Type', 'application/json'
    )
  )::text;
  $$
);
```

4. **Add UI Buttons** (Web - React/Next.js):
```typescript
// frontend/src/features/settings/account-actions.tsx
import { useState } from 'react';
import { deleteAccount, exportUserData } from '@/services/auth';

export function AccountActions() {
  const [isDeleting, setIsDeleting] = useState(false);
  
  const handleExportData = async () => {
    const response = await exportUserData();
    // Trigger download
    const link = document.createElement('a');
    link.href = URL.createObjectURL(response);
    link.download = `export-${Date.now()}.json`;
    link.click();
  };
  
  const handleDeleteAccount = async () => {
    const confirmation = prompt(
      'Type DELETE MY ACCOUNT to confirm permanent deletion (14-day grace period):'
    );
    
    if (confirmation !== 'DELETE MY ACCOUNT') {
      alert('Confirmation phrase does not match');
      return;
    }
    
    setIsDeleting(true);
    try {
      const { gracePeriodEndsAt } = await deleteAccount(confirmation);
      alert(`Account scheduled for deletion on ${new Date(gracePeriodEndsAt).toLocaleDateString()}`);
      // Redirect to logout
      window.location.href = '/logout';
    } catch (error) {
      alert('Failed to delete account: ' + error.message);
    } finally {
      setIsDeleting(false);
    }
  };
  
  return (
    <div className="space-y-4">
      <button onClick={handleExportData}>Download My Data</button>
      <button onClick={handleDeleteAccount} disabled={isDeleting} className="text-red-600">
        {isDeleting ? 'Deleting...' : 'Delete Account'}
      </button>
    </div>
  );
}
```

5. **Add UI Buttons** (Flutter):
```dart
// lib/features/settings/account_actions_button.dart
class AccountActionsButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () => _showExportConfirmation(context),
          child: Text('Download My Data'),
        ),
        SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => _showDeleteConfirmation(context),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: Text('Delete Account', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  void _showExportConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Download Your Data'),
        content: Text('Export will include mood logs, comments, and wallet history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await _exportData(context);
              Navigator.pop(context);
            },
            child: Text('Export'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('This will delete your account after a 14-day grace period.'),
            SizedBox(height: 16),
            Text('To confirm, type: DELETE MY ACCOUNT'),
            SizedBox(height: 8),
            TextField(controller: controller, decoration: InputDecoration(border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: controller.text == 'DELETE MY ACCOUNT'
                ? () async {
                    await _deleteAccount(context);
                    Navigator.pop(context);
                  }
                : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Confirm Deletion', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    // Call export-user-data endpoint and save to device
  }

  Future<void> _deleteAccount(BuildContext context) async {
    // Call delete-account endpoint
  }
}
```

**Verification**:
```bash
# Test soft-delete
curl -X POST https://[project].supabase.co/functions/v1/delete-account \
  -H "Authorization: Bearer [token]" \
  -H "Content-Type: application/json" \
  -d '{"userId":"[user-id]","confirmationPhrase":"DELETE MY ACCOUNT"}'

# Should return 200 with gracePeriodEndsAt

# Test data export
curl -X GET https://[project].supabase.co/functions/v1/export-user-data \
  -H "Authorization: Bearer [token]"

# Should return JSON file download
```

### Issue #593: AI Insight Generation Fix

**Why**: Users stuck in loading state represents broken feature. Needs reliable trigger.

**Files**: `issue-593-ai-insight-fix.md`

**Implementation**:
1. Run the Postgres trigger migration (adds automatic generation on 3rd log)
2. Update Flutter UI with error state and retry button
3. Add timeout handling (30 second timeout)
4. Implement manual "Generate Insight" button as fallback

**Testing**:
```bash
# Create test user and add 2 logs (no insight yet)
INSERT INTO log_entries (user_id, mood, notes) VALUES ('[user-id]', 5, 'Test');
INSERT INTO log_entries (user_id, mood, notes) VALUES ('[user-id]', 6, 'Test');

# Verify no insight
SELECT * FROM insights WHERE user_id = '[user-id]'; -- Should be empty

# Add 3rd log (should trigger generation automatically)
INSERT INTO log_entries (user_id, mood, notes) VALUES ('[user-id]', 7, 'Test');

# Wait 10 seconds and check if insight was generated
SELECT * FROM insights WHERE user_id = '[user-id]'; -- Should have data
```

### Issue #594: Global Mirror Implementation Audit

**Why**: Specification unclear if complete or has gaps. Tests needed.

**Files**: `issue-594-global-mirror-audit.md`

**Implementation**:
1. Run comprehensive test suite
2. Verify each feature in the header comment works
3. Fix any gaps found
4. Add test coverage for clustering and realtime logic

**Test Execution**:
```bash
npm test -- global-mirror.test.ts
npm test -- clustering.test.ts

# Should have >90% coverage on:
# - Clustering logic
# - Realtime subscription handling
# - Theme switching
```

## Deployment Checklist

### Pre-Production
- [ ] #595: All Edge Functions use structured logger
- [ ] #592: Database migration applied
- [ ] #592: All 3 delete/export functions deployed
- [ ] #592: pg_cron scheduled job configured
- [ ] #592: UI buttons added to web and Flutter
- [ ] #593: Insight trigger migration applied
- [ ] #593: Flutter UI updated with error handling
- [ ] #594: All tests pass with >90% coverage

### Production Rollout
- [ ] Monitor structured logs for first 24 hours
- [ ] Test account deletion with real user (soft delete)
- [ ] Verify data export produces valid JSON
- [ ] Confirm grace period recovery works
- [ ] Monitor AI insight generation success rate
- [ ] Verify global mirror features all work

### Post-Deployment
- [ ] Document any issues found
- [ ] Collect user feedback on deletion flow UX
- [ ] Monitor trace ID correlation effectiveness
- [ ] Track insight generation failure rates

## Monitoring

### Structured Logs Query (Supabase)

```sql
-- Find all errors in delete-account function
SELECT json_data->>'message' as message, 
       COUNT(*) as count
FROM logs
WHERE json_data->>'functionName' = 'delete-account'
  AND json_data->>'level' = 'error'
GROUP BY message;

-- Trace a single request
SELECT json_data
FROM logs
WHERE json_data->>'requestId' = '[trace-id]'
ORDER BY json_data->>'timestamp';

-- Monitor deletion success rate
SELECT 
  COUNT(*) FILTER (WHERE json_data->>'level' = 'info' AND json_data->>'message' LIKE 'soft%') as soft_deletes,
  COUNT(*) FILTER (WHERE json_data->>'level' = 'error') as failures,
  ROUND(100.0 * COUNT(*) FILTER (WHERE json_data->>'level' = 'info') 
        / COUNT(*), 2) as success_rate_percent
FROM logs
WHERE json_data->>'functionName' IN ('delete-account', 'hard-delete-accounts')
  AND date_part('day', now() - json_data->>'timestamp'::timestamp) <= 1;
```

## Troubleshooting

### Issue: Soft-deleted accounts not auto-deleting
- Check pg_cron is enabled: `SELECT * FROM cron.job;`
- Check Edge Function logs for hard-delete-accounts
- Verify SERVICE_ROLE_KEY in cron job authorization

### Issue: Insights never generate
- Check Postgres trigger exists: `SELECT * FROM pg_trigger WHERE tgname LIKE '%insight%';`
- Check generate-insight function logs
- Manually trigger: `SELECT trigger_generate_insight_on_threshold();`

### Issue: Trace IDs not appearing in logs
- Verify logger.ts is in `_shared/` directory
- Check all Edge Functions import from `_shared/logger`
- Verify extractTraceId is called with request headers

### Issue: Global Mirror clusters not forming
- Run clustering tests: `npm test -- clustering.test.ts`
- Check zoom level matches threshold
- Verify pins have valid latitude/longitude

## Next Steps

1. **Immediate** (Today)
   - Set up structured logging (#595)
   - Apply database migration (#592)
   - Deploy delete/export functions (#592)

2. **This Week**
   - Complete account deletion UI (#592)
   - Fix insight generation (#593)
   - Deploy scheduled hard-delete job (#592)

3. **This Sprint**
   - Audit and complete global mirror (#594)
   - Monitor and adjust logging verbosity
   - Gather user feedback on deletion UX

4. **Future**
   - Consider implementing recovery from soft-delete
   - Add email notifications for deletion timeline
   - Expand logging to other services
   - Add compliance audit logs

## Support

- **Structured Logging Questions**: See `logger.ts` comments
- **Account Deletion Issues**: Check database migration and Edge Function logs
- **Insight Generation Issues**: Monitor insight generation trigger and timeout handling
- **Global Mirror Issues**: Review test coverage and audit findings

---

Generated: 2024-07-25
Issues: #592, #593, #594, #595
Status: Ready for Implementation
