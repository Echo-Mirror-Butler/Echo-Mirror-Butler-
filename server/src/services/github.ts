import { createClient } from '@supabase/supabase-js';

interface GitHubIssue {
  id: number;
  number: number;
  title: string;
  body: string | null;
  state: 'open' | 'closed';
  created_at: string;
  updated_at: string;
  user: {
    id: number;
    login: string;
  };
  labels: Array<{
    id: number;
    name: string;
  }>;
}

interface SyncedIssue {
  github_id: number;
  github_number: number;
  title: string;
  body: string | null;
  state: string;
  created_at: string;
  updated_at: string;
  user_login: string;
  labels: string[];
  sync_source: 'cli' | 'api' | 'webhook';
  synced_at: string;
}

class GitHubService {
  private supabase: ReturnType<typeof createClient>;
  private githubToken: string;
  private repoOwner: string;
  private repoName: string;

  constructor() {
    this.supabase = createClient(
      process.env.SUPABASE_URL || '',
      process.env.SUPABASE_SERVICE_ROLE_KEY || ''
    );
    this.githubToken = process.env.GITHUB_TOKEN || '';
    this.repoOwner = process.env.GITHUB_REPO_OWNER || '';
    this.repoName = process.env.GITHUB_REPO_NAME || '';
  }

  /**
   * Detect issue creation source based on event patterns
   * CLI-created issues typically have different patterns than API-created ones
   */
  private detectCreationSource(issue: GitHubIssue): 'cli' | 'api' | 'webhook' {
    // API-created issues often have specific patterns in the body or metadata
    // This is a heuristic - adjust based on your actual API behavior
    if (issue.body?.includes('via GrantFox MCP') || 
        issue.body?.includes('API-created') ||
        issue.labels.some(l => l.name.includes('api'))) {
      return 'api';
    }
    
    // CLI-created issues typically don't have API markers
    if (issue.body?.includes('via GitHub CLI') || 
        issue.labels.some(l => l.name.includes('cli'))) {
      return 'cli';
    }
    
    // Default to webhook for issues created through web interface
    return 'webhook';
  }

  /**
   * Sync a GitHub issue to the maintainer dashboard
   */
  async syncIssue(issue: GitHubIssue): Promise<SyncedIssue | null> {
    try {
      const syncSource = this.detectCreationSource(issue);
      
      const syncedIssue: SyncedIssue = {
        github_id: issue.id,
        github_number: issue.number,
        title: issue.title,
        body: issue.body,
        state: issue.state,
        created_at: issue.created_at,
        updated_at: issue.updated_at,
        user_login: issue.user.login,
        labels: issue.labels.map(l => l.name),
        sync_source: syncSource,
        synced_at: new Date().toISOString()
      };

      // Upsert to Supabase
      const { error } = await this.supabase
        .from('github_issues')
        .upsert(syncedIssue as any, {
          onConflict: 'github_id'
        });

      if (error) {
        console.error('Failed to sync issue to Supabase:', error);
        return null;
      }

      console.log(`Synced issue #${issue.number} (source: ${syncSource})`);
      return syncedIssue;
    } catch (error) {
      console.error('Error syncing issue:', error);
      return null;
    }
  }

  /**
   * Fetch an issue from GitHub API
   */
  async fetchIssue(issueNumber: number): Promise<GitHubIssue | null> {
    try {
      const response = await fetch(
        `https://api.github.com/repos/${this.repoOwner}/${this.repoName}/issues/${issueNumber}`,
        {
          headers: {
            'Authorization': `Bearer ${this.githubToken}`,
            'Accept': 'application/vnd.github.v3+json'
          }
        }
      );

      if (!response.ok) {
        console.error(`GitHub API error: ${response.status}`);
        return null;
      }

      const issue = await response.json() as GitHubIssue;
      return issue;
    } catch (error) {
      console.error('Error fetching issue from GitHub:', error);
      return null;
    }
  }

  /**
   * Test sync for a specific issue number
   * This is used to verify sync behavior for CLI vs API created issues
   */
  async testIssueSync(issueNumber: number): Promise<{
    success: boolean;
    issue: GitHubIssue | null;
    syncedIssue: SyncedIssue | null;
    syncSource: string;
  }> {
    console.log(`Testing sync for issue #${issueNumber}`);
    
    const issue = await this.fetchIssue(issueNumber);
    if (!issue) {
      return {
        success: false,
        issue: null,
        syncedIssue: null,
        syncSource: 'unknown'
      };
    }

    const syncedIssue = await this.syncIssue(issue);
    const syncSource = this.detectCreationSource(issue);

    return {
      success: syncedIssue !== null,
      issue,
      syncedIssue,
      syncSource
    };
  }

  /**
   * Get all synced issues from the dashboard
   */
  async getSyncedIssues(): Promise<SyncedIssue[]> {
    try {
      const { data, error } = await this.supabase
        .from('github_issues')
        .select('*')
        .order('synced_at', { ascending: false });

      if (error) {
        console.error('Error fetching synced issues:', error);
        return [];
      }

      return data || [];
    } catch (error) {
      console.error('Error fetching synced issues:', error);
      return [];
    }
  }
}

export default GitHubService;
