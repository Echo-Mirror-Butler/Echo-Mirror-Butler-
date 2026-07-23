# GitHub Issue Sync Service

This service enables syncing GitHub issues to a maintainer dashboard for tracking and analysis, with specific support for distinguishing between CLI-created and API-created issues.

## Purpose

The GitHub Issue Sync Service was created to isolate and test whether maintainer dashboard sync issues are specific to API-created issues (via GrantFox MCP) versus CLI-created issues (via GitHub CLI).

## Features

- **Issue Source Detection**: Automatically detects whether issues were created via CLI, API, or web interface
- **Sync to Supabase**: Stores synced issues in a `github_issues` table for dashboard display
- **Webhook Support**: Listens for GitHub webhook events to trigger automatic syncs
- **Test Functionality**: Includes test methods to verify sync behavior for different issue sources

## Setup

### 1. Database Migration

Run the migration to create the `github_issues` table:

```bash
supabase db push
```

Or apply the migration manually:
```bash
supabase migration up
```

### 2. Environment Variables

Add the following to your `server/.env` file:

```bash
GITHUB_TOKEN=your-github-personal-access-token
GITHUB_REPO_OWNER=your-github-username-or-org
GITHUB_REPO_NAME=your-repository-name
```

**GitHub Token Requirements:**
- Create a Personal Access Token at https://github.com/settings/tokens
- Required scopes: `repo:public_repo` (or `repo` for private repositories)

### 3. Install Dependencies

The service uses existing dependencies in the project:
- `@supabase/supabase-js` - Supabase client
- `express` - Web server

## Usage

### Manual Sync Test

Test sync for a specific issue:

```typescript
import GitHubService from './services/github';

const githubService = new GitHubService();
const result = await githubService.testIssueSync(123);

console.log('Sync result:', result);
// { success: boolean, issue: GitHubIssue | null, syncedIssue: SyncedIssue | null, syncSource: string }
```

### Webhook Integration

Set up a GitHub webhook to point to your server:

1. Go to your repository Settings → Webhooks
2. Add webhook: `https://your-server.com/webhooks/github`
3. Select events: `Issues` and `Issue comments`
4. Set webhook secret (optional but recommended)

The webhook handler will automatically sync issues when they are:
- Opened
- Edited
- Closed
- Reopened

### API Endpoints

#### POST /webhooks/github
Receives GitHub webhook events and triggers issue sync.

**Headers:**
- `x-hub-signature-256`: Webhook signature for verification
- `x-github-event`: Event type (e.g., `issues`, `issue_comment`)

**Response:**
```json
{
  "received": true
}
```

## Issue Source Detection

The service uses heuristics to detect how an issue was created:

### API-Created Issues
- Body contains "via GrantFox MCP" or "API-created"
- Labels include "api"

### CLI-Created Issues
- Body contains "via GitHub CLI"
- Labels include "cli"

### Webhook-Created Issues (Default)
- Issues created through GitHub web interface
- No specific markers detected

## Testing

Run the test suite:

```bash
cd server
npm test
```

The test suite includes:
- Source detection tests for CLI, API, and webhook issues
- Sync behavior verification
- Error handling tests
- Integration tests for comparing sync behavior

## Database Schema

### github_issues Table

| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| github_id | bigint | GitHub issue ID (unique) |
| github_number | int | GitHub issue number |
| title | text | Issue title |
| body | text | Issue body |
| state | text | Issue state (open/closed) |
| created_at | timestamptz | GitHub creation timestamp |
| updated_at | timestamptz | GitHub last update timestamp |
| user_login | text | Issue creator username |
| labels | jsonb | Array of label names |
| sync_source | text | Source: cli/api/webhook |
| synced_at | timestamptz | When synced to database |

## Troubleshooting

### Sync Not Working
1. Verify GitHub token has correct permissions
2. Check environment variables are set correctly
3. Ensure Supabase migration has been applied
4. Check server logs for error messages

### Webhook Not Receiving Events
1. Verify webhook URL is publicly accessible
2. Check GitHub webhook delivery logs
3. Ensure webhook secret matches (if configured)
4. Verify event types are selected in webhook settings

### Source Detection Incorrect
- Adjust detection logic in `detectCreationSource()` method
- Add custom labels to issues to explicitly mark source
- Update issue body patterns for better detection

## Security Considerations

- GitHub webhook signature verification should be implemented (currently TODO)
- Use environment variables for sensitive credentials
- Restrict GitHub token to minimum required scopes
- Implement rate limiting for webhook endpoints
- Consider IP whitelisting for webhook endpoints

## Future Enhancements

- [ ] Implement webhook signature verification
- [ ] Add support for pull request sync
- [ ] Create maintainer dashboard UI
- [ ] Add sync status monitoring
- [ ] Implement retry logic for failed syncs
- [ ] Add support for issue comments sync
- [ ] Create analytics for sync performance
