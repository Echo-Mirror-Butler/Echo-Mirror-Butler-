import { describe, it, expect, beforeAll, afterAll } from '@jest/globals';
import GitHubService from './github';
import { createClient } from '@supabase/supabase-js';

// Mock Supabase client
jest.mock('@supabase/supabase-js');

describe('GitHub Issue Sync Service - CLI vs API Test', () => {
  let githubService: GitHubService;
  let mockSupabaseClient: any;

  beforeAll(() => {
    // Setup environment variables for testing
    process.env.GITHUB_TOKEN = 'test-token';
    process.env.GITHUB_REPO_OWNER = 'test-owner';
    process.env.GITHUB_REPO_NAME = 'test-repo';
    process.env.SUPABASE_URL = 'https://test.supabase.co';
    process.env.SUPABASE_SERVICE_ROLE_KEY = 'test-service-key';

    // Create mock Supabase client
    mockSupabaseClient = {
      from: jest.fn().mockReturnValue({
        upsert: jest.fn().mockResolvedValue({ error: null }),
        select: jest.fn().mockReturnValue({
          order: jest.fn().mockResolvedValue({ data: [], error: null })
        })
      })
    };

    (createClient as jest.Mock).mockReturnValue(mockSupabaseClient);
    
    githubService = new GitHubService();
  });

  afterAll(() => {
    jest.clearAllMocks();
  });

  describe('Issue Creation Source Detection', () => {
    it('should detect API-created issues', () => {
      const apiIssue = {
        id: 1,
        number: 100,
        title: 'Test API Issue',
        body: 'This issue was created via GrantFox MCP',
        state: 'open' as const,
        created_at: '2024-01-01T00:00:00Z',
        updated_at: '2024-01-01T00:00:00Z',
        user: { id: 1, login: 'testuser' },
        labels: []
      };

      // Access private method via type assertion for testing
      const detectSource = (githubService as any).detectCreationSource.bind(githubService);
      const source = detectSource(apiIssue);
      
      expect(source).toBe('api');
    });

    it('should detect CLI-created issues', () => {
      const cliIssue = {
        id: 2,
        number: 101,
        title: 'Test CLI Issue',
        body: 'Test issue created directly via GitHub CLI',
        state: 'open' as const,
        created_at: '2024-01-01T00:00:00Z',
        updated_at: '2024-01-01T00:00:00Z',
        user: { id: 1, login: 'testuser' },
        labels: []
      };

      const detectSource = (githubService as any).detectCreationSource.bind(githubService);
      const source = detectSource(cliIssue);
      
      expect(source).toBe('webhook'); // Default for CLI-created without explicit marker
    });

    it('should detect CLI-created issues with explicit marker', () => {
      const cliIssueWithMarker = {
        id: 3,
        number: 102,
        title: 'Test CLI Issue with Marker',
        body: 'This issue was created via GitHub CLI',
        state: 'open' as const,
        created_at: '2024-01-01T00:00:00Z',
        updated_at: '2024-01-01T00:00:00Z',
        user: { id: 1, login: 'testuser' },
        labels: []
      };

      const detectSource = (githubService as any).detectCreationSource.bind(githubService);
      const source = detectSource(cliIssueWithMarker);
      
      expect(source).toBe('cli');
    });

    it('should detect webhook-created issues as default', () => {
      const webhookIssue = {
        id: 4,
        number: 103,
        title: 'Test Webhook Issue',
        body: 'Regular issue created via GitHub web interface',
        state: 'open' as const,
        created_at: '2024-01-01T00:00:00Z',
        updated_at: '2024-01-01T00:00:00Z',
        user: { id: 1, login: 'testuser' },
        labels: []
      };

      const detectSource = (githubService as any).detectCreationSource.bind(githubService);
      const source = detectSource(webhookIssue);
      
      expect(source).toBe('webhook');
    });
  });

  describe('Issue Sync Behavior', () => {
    it('should sync API-created issue with correct source', async () => {
      const apiIssue = {
        id: 1,
        number: 100,
        title: 'Test API Issue',
        body: 'Created via GrantFox MCP',
        state: 'open' as const,
        created_at: '2024-01-01T00:00:00Z',
        updated_at: '2024-01-01T00:00:00Z',
        user: { id: 1, login: 'testuser' },
        labels: []
      };

      const result = await githubService.syncIssue(apiIssue);
      
      expect(result).not.toBeNull();
      expect(result?.sync_source).toBe('api');
      expect(mockSupabaseClient.from).toHaveBeenCalledWith('github_issues');
    });

    it('should sync CLI-created issue with correct source', async () => {
      const cliIssue = {
        id: 2,
        number: 101,
        title: 'Test CLI Issue',
        body: 'Test issue created directly via GitHub CLI',
        state: 'open' as const,
        created_at: '2024-01-01T00:00:00Z',
        updated_at: '2024-01-01T00:00:00Z',
        user: { id: 1, login: 'testuser' },
        labels: []
      };

      const result = await githubService.syncIssue(cliIssue);
      
      expect(result).not.toBeNull();
      expect(result?.sync_source).toBe('webhook'); // Default for CLI without marker
      expect(mockSupabaseClient.from).toHaveBeenCalledWith('github_issues');
    });

    it('should handle sync errors gracefully', async () => {
      const errorIssue = {
        id: 3,
        number: 102,
        title: 'Test Error Issue',
        body: 'This should cause an error',
        state: 'open' as const,
        created_at: '2024-01-01T00:00:00Z',
        updated_at: '2024-01-01T00:00:00Z',
        user: { id: 1, login: 'testuser' },
        labels: []
      };

      // Mock Supabase error
      mockSupabaseClient.from = jest.fn().mockReturnValue({
        upsert: jest.fn().mockResolvedValue({ error: new Error('Database error') })
      });

      const result = await githubService.syncIssue(errorIssue);
      
      expect(result).toBeNull();
    });
  });

  describe('Test Issue Sync Integration', () => {
    it('should test sync for a specific issue number', async () => {
      // Mock fetch response
      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          id: 1,
          number: 100,
          title: 'Test Issue',
          body: 'Test body',
          state: 'open',
          created_at: '2024-01-01T00:00:00Z',
          updated_at: '2024-01-01T00:00:00Z',
          user: { id: 1, login: 'testuser' },
          labels: []
        })
      }) as jest.Mock;

      const result = await githubService.testIssueSync(100);
      
      expect(result.success).toBe(true);
      expect(result.issue).not.toBeNull();
      expect(result.syncedIssue).not.toBeNull();
      expect(result.syncSource).toBeDefined();
    });

    it('should handle fetch errors in test sync', async () => {
      global.fetch = jest.fn().mockResolvedValue({
        ok: false
      }) as jest.Mock;

      const result = await githubService.testIssueSync(999);
      
      expect(result.success).toBe(false);
      expect(result.issue).toBeNull();
      expect(result.syncedIssue).toBeNull();
    });
  });

  describe('Sync Comparison Test', () => {
    it('should verify both CLI and API issues sync to same table', async () => {
      const cliIssue = {
        id: 2,
        number: 101,
        title: 'CLI Test Issue',
        body: 'Created via CLI',
        state: 'open' as const,
        created_at: '2024-01-01T00:00:00Z',
        updated_at: '2024-01-01T00:00:00Z',
        user: { id: 1, login: 'testuser' },
        labels: []
      };

      const apiIssue = {
        id: 1,
        number: 100,
        title: 'API Test Issue',
        body: 'Created via GrantFox MCP',
        state: 'open' as const,
        created_at: '2024-01-01T00:00:00Z',
        updated_at: '2024-01-01T00:00:00Z',
        user: { id: 1, login: 'testuser' },
        labels: []
      };

      // Reset mock
      mockSupabaseClient.from = jest.fn().mockReturnValue({
        upsert: jest.fn().mockResolvedValue({ error: null })
      });

      const cliResult = await githubService.syncIssue(cliIssue);
      const apiResult = await githubService.syncIssue(apiIssue);

      // Both should successfully sync
      expect(cliResult).not.toBeNull();
      expect(apiResult).not.toBeNull();

      // Both should call the same table
      expect(mockSupabaseClient.from).toHaveBeenCalledWith('github_issues');

      // They should have different sync sources
      expect(cliResult?.sync_source).not.toBe(apiResult?.sync_source);
    });
  });
});
