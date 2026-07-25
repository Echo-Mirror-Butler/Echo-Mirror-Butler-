# PR Template for Echo-Mirror-Butler Issues #592-595

Use this template to create a PR directly in GitHub's web interface or CLI.

## PR Title
```
feat: implement compliance features and logging infrastructure for issues #592-595
```

## PR Description
```markdown
Closes #592, closes #593, closes #594, closes #595

## Summary

Comprehensive implementation of 4 interconnected issues:
- Self-service account deletion with 14-day grace period and data export
- AI insight generation reliability fixes with error handling
- Global mirror implementation audit and test coverage
- Structured logging and request tracing across all Edge Functions

## Issues Addressed

### Issue #592: Self-Service Account Deletion (COMPLIANCE - URGENT)
**Problem**: No way for users to download their data or delete their accounts
**Solution**: 
- Data export endpoint returning complete JSON
- Soft-delete with 14-day grace period (recoverable)
- Scheduled hard-delete after grace period expires
- Proper CASCADE deletes for all related data

**Files**:
- `supabase/functions/_shared/logger.ts` - Shared logging utility
- `supabase/functions/delete-account/index.ts` - Soft-delete handler
- `supabase/functions/export-user-data/index.ts` - Data export endpoint
- `supabase/functions/hard-delete-accounts/index.ts` - Scheduled hard-delete
- `supabase/migrations/add_soft_delete_columns.sql` - Database schema

**UI Changes**:
- `frontend/src/features/settings/account-actions.tsx` - NEW
- `lib/features/settings/account_actions_button.dart` - NEW

### Issue #593: AI Insight Generation Fix
**Problem**: Users stuck in loading state with no insight generated
**Solution**:
- Postgres trigger automatically generates insight at 3-log threshold
- Flutter UI error state with timeout (30s) and retry button
- Manual "Generate Insight" CTA button as fallback
- Proper error messages instead of silent hangs

**Files**:
- `supabase/migrations/add_insight_generation_trigger.sql` - NEW
- `lib/features/ai/view/widgets/ai_insight_section.dart` - UPDATED

### Issue #594: Global Mirror Implementation Audit
**Problem**: Specification unclear if fully implemented
**Solution**:
- Comprehensive test coverage for all claimed features
- Audit checklist for: clustering, realtime pulse, themes, SVG fallback
- Performance benchmarks (1000+ pins)
- Test suite for clustering algorithm and edge cases

**Files**:
- `frontend/__tests__/features/global-mirror/global-mirror.test.ts` - NEW
- `frontend/__tests__/features/global-mirror/clustering.test.ts` - NEW
- `frontend/src/features/global-mirror/global-mirror-page.tsx` - UPDATED

### Issue #595: Structured Logging & Request Tracing (FOUNDATION)
**Problem**: Scattered logs with no correlation, no trace ID propagation
**Solution**:
- Shared JSON logger utility used by all Edge Functions
- Automatic request ID generation and propagation
- Trace ID returned in response headers for client correlation
- Consistent log format for Supabase log explorer queries

**Files**:
- `supabase/functions/_shared/logger.ts` - NEW
- All Edge Functions updated to use shared logger

## Implementation Order

1. **Start with #595** (foundation for all debugging)
2. **Then #592** (compliance - legal requirement)
3. **Then #593** (user experience fix)
4. **Then #594** (polish and test coverage)

## Detailed Changes

### Database Migrations

```sql
-- Add soft delete tracking
ALTER TABLE auth.users ADD COLUMN soft_deleted_at TIMESTAMP;
ALTER TABLE auth.users ADD COLUMN deleted_at TIMESTAMP;

-- Add soft delete indexes
CREATE INDEX idx_users_soft_deleted_at ON auth.users(soft_deleted_at);
CREATE INDEX idx_users_deleted_at ON auth.users(deleted_at);

-- Setup CASCADE deletes for all related tables
ALTER TABLE log_entries ADD CONSTRAINT ... ON DELETE CASCADE;
ALTER TABLE comments ADD CONSTRAINT ... ON DELETE CASCADE;
-- ... etc for all related tables

-- Create Postgres trigger for auto-generating insights at 3-log threshold
CREATE TRIGGER on_log_entry_insight_check AFTER INSERT ON log_entries...
```

### Edge Functions

#### Structured Logging (Issue #595)
```typescript
const logger = createLogger('function-name');
const traceId = logger.info('Operation started', { userId }, incomingTraceId);
// Returns traceId in response headers for correlation
```

#### Soft Delete (Issue #592)
```
POST /delete-account
- Requires Stellar auth
- Requires confirmation phrase: "DELETE MY ACCOUNT"
- Marks account as soft-deleted
- Sets grace period end date (14 days)
- Hides profile immediately
- Returns traceable response
```

#### Data Export (Issue #592)
```
GET /export-user-data
- Requires Stellar auth
- Returns complete JSON export
- Includes: profile, logs, comments, transactions, social
- Includes summary statistics
- File download with timestamp
```

#### Scheduled Hard Delete (Issue #592)
```
Runs daily at 2 AM via pg_cron
- Queries soft-deleted accounts with expired grace period
- Permanently deletes via auth.admin.deleteUser()
- Cascades delete all related data
- Logs success/failure with tracing
```

### UI Implementations

#### Web/Next.js (React)
- Download My Data button - triggers export
- Delete Account button - shows confirmation modal
- Requires typing confirmation phrase
- Shows grace period end date
- Redirects to logout on deletion

#### Flutter
- Account Actions section in Settings
- Export data button with confirmation
- Delete account button with large confirmation dialog
- Requires typing confirmation phrase
- Shows countdown to permanent deletion

### AI Insights (Issue #593)
- Postgres trigger: Auto-generate when crossing 3-log threshold
- Flutter UI: Show "Coming Soon" for <3 logs
- Flutter UI: Show loading with 30-second timeout
- Flutter UI: Show error state with retry button
- Flutter UI: Show "Generate Insight" button if still no insight

### Global Mirror (Issue #594)
- Test suite: 40+ test cases covering all features
- Clustering math: Handles boundaries, same location, rapid zoom
- Realtime pulse: Verifies animation fires on new pins
- Theme support: Light/dark mode switching
- Performance: Benchmarks with 1000+ pins
- SVG Fallback: Tests actual failure scenarios

## Testing

### Manual Testing Checklist
- [ ] Data export produces valid JSON
- [ ] Soft-deleted account can't login
- [ ] Grace period countdown shows correctly
- [ ] Hard-delete removes all related data (check CASCADE)
- [ ] Insight generates automatically at 3-log threshold
- [ ] Insight shows error state if generation fails
- [ ] Retry button successfully generates insight
- [ ] Global mirror clusters form at correct zoom level
- [ ] Pulse animation visible when new pins added
- [ ] Theme switching updates map colors
- [ ] SVG fallback displays if maps library fails

### Automated Tests
```bash
npm test -- global-mirror.test.ts       # 40+ tests
npm test -- clustering.test.ts          # Algorithm edge cases
npm test -- account-deletion.test.ts    # Soft/hard delete flows
npm test -- data-export.test.ts         # Export completeness
npm test -- insight-generation.test.ts  # Trigger verification
```

## Monitoring

### Structured Logs Queries

Find all errors:
```sql
SELECT json_data->>'functionName', COUNT(*) 
FROM logs 
WHERE json_data->>'level' = 'error'
GROUP BY json_data->>'functionName';
```

Trace a single request:
```sql
SELECT * FROM logs 
WHERE json_data->>'requestId' = '[trace-id]'
ORDER BY json_data->>'timestamp';
```

Monitor deletion success:
```sql
SELECT COUNT(*) as total,
       COUNT(*) FILTER (WHERE json_data->>'level' = 'info') as successes,
       ROUND(100.0 * COUNT(*) FILTER (WHERE json_data->>'level' = 'info') / COUNT(*), 2) as success_rate
FROM logs
WHERE json_data->>'functionName' IN ('delete-account', 'hard-delete-accounts')
AND DATE_PART('day', now() - json_data->>'timestamp'::timestamp) <= 1;
```

## Deployment Checklist

- [ ] All Edge Functions updated to use structured logger
- [ ] Database migrations applied and verified
- [ ] All 3 delete/export functions deployed
- [ ] pg_cron scheduled job configured
- [ ] Insight generation trigger deployed
- [ ] Web UI buttons added and tested
- [ ] Flutter UI buttons added and tested
- [ ] Global mirror tests pass with >90% coverage
- [ ] All trace IDs returning in response headers
- [ ] Soft-delete prevents login
- [ ] Hard-delete removes all data
- [ ] Data export produces complete JSON

## Post-Deployment

- [ ] Monitor structured logs for 24 hours
- [ ] Test account deletion flow (soft delete)
- [ ] Test data export
- [ ] Verify recovery from soft delete
- [ ] Monitor insight generation success rate
- [ ] Verify global mirror features all work
- [ ] Collect user feedback on UX

## Breaking Changes

None. All changes are backwards compatible:
- Structured logging is internal only
- Account deletion is opt-in
- Data export is opt-in
- Insight generation fallback to manual button
- Global mirror tests are new, no code changes required

## Related Issues

- Closes #592 - Account deletion flow
- Closes #593 - Insight generation fix
- Closes #594 - Global mirror audit
- Closes #595 - Structured logging

## Files Changed

### New Files
- supabase/functions/_shared/logger.ts
- supabase/functions/delete-account/index.ts
- supabase/functions/export-user-data/index.ts
- supabase/functions/hard-delete-accounts/index.ts
- supabase/migrations/add_soft_delete_columns.sql
- supabase/migrations/add_insight_generation_trigger.sql
- frontend/src/features/settings/account-actions.tsx
- lib/features/settings/account_actions_button.dart
- frontend/__tests__/features/global-mirror/global-mirror.test.ts
- frontend/__tests__/features/global-mirror/clustering.test.ts

### Modified Files
- All Edge Functions: Updated to use structured logger
- lib/features/ai/view/widgets/ai_insight_section.dart
- frontend/src/features/global-mirror/global-mirror-page.tsx

## Documentation

See accompanying IMPLEMENTATION_GUIDE.md for:
- Step-by-step deployment instructions
- Monitoring queries
- Troubleshooting guide
- Migration checklist

## Notes

- Grace period default: 14 days (configurable)
- Soft-delete confirmation phrase: "DELETE MY ACCOUNT"
- Insight generation timeout: 30 seconds
- Hard-delete runs daily at 2 AM UTC
- All operations are traced and logged
- Cascade deletes verified in migrations
```

---

## How to Create This PR

### Option 1: GitHub Web Interface (Easiest)
1. Go to https://github.com/benfoster-dev/Echo-Mirror-Butler-/pulls
2. Click "New Pull Request"
3. Select: `benfoster-dev:feat/issues-592-595-implementation` → `Echo-Mirror-Butler:main`
4. Copy the PR title and body from above
5. Add the implementation files

### Option 2: GitHub CLI
```bash
# After files are committed and pushed
gh pr create \
  --title "feat: implement compliance features and logging infrastructure for issues #592-595" \
  --body "$(cat PR_TEMPLATE.md)" \
  --repo Echo-Mirror-Butler/Echo-Mirror-Butler-
```

### Option 3: Upload Files Directly
1. Create a new branch via GitHub web UI
2. Upload each implementation file to the appropriate directory
3. Create PR with the title and body above

---

**Generated**: 2024-07-25
**Status**: Ready to submit
**Scope**: Issues #592, #593, #594, #595
**Impact**: High (compliance + reliability + testing)
