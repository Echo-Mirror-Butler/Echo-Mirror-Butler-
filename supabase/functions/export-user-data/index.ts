/**
 * Issue #592: Account Deletion Flow - Improved Data Export Function
 *
 * This Edge Function exports a complete user data dump including:
 * - Profile information
 * - Mood logs with all fields
 * - Comments/notes
 * - Wallet transactions
 * - Social connections (followers/following)
 *
 * Returns JSON file ready for download
 *
 * GET /export-user-data
 * Response: { userId, exportedAt, data: { profiles, logs, comments, transactions, social } }
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { createLogger, extractTraceId, addTraceIdToResponse } from '../_shared/logger.ts';

const logger = createLogger('export-user-data');

export async function exportUserDataFunction(req: Request): Promise<Response> {
  const incomingTraceId = extractTraceId(Object.fromEntries(req.headers));
  let traceId = incomingTraceId;

  try {
    // Verify request method
    if (req.method !== 'GET') {
      const errorTraceId = logger.warn('Invalid request method', { method: req.method }, traceId);
      traceId = errorTraceId;
      return new Response(
        JSON.stringify({ error: 'Method not allowed', traceId }),
        {
          status: 405,
          headers: addTraceIdToResponse({ 'Content-Type': 'application/json' }, traceId),
        }
      );
    }

    // Extract user ID from Authorization header (JWT)
    const authHeader = req.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      const errorTraceId = logger.warn('Missing authorization header', {}, traceId);
      traceId = errorTraceId;
      return new Response(
        JSON.stringify({ error: 'Unauthorized', traceId }),
        {
          status: 401,
          headers: addTraceIdToResponse({ 'Content-Type': 'application/json' }, traceId),
        }
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!supabaseUrl || !supabaseKey) {
      const errorTraceId = logger.error(
        'Missing Supabase credentials',
        'Configuration error',
        {},
        traceId
      );
      traceId = errorTraceId;
      return new Response(
        JSON.stringify({ error: 'Server configuration error', traceId }),
        { status: 500, headers: addTraceIdToResponse({ 'Content-Type': 'application/json' }, traceId) }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    // Get authenticated user from JWT
    const token = authHeader.slice(7);
    const { data: userData, error: authError } = await supabase.auth.getUser(token);

    if (authError || !userData.user) {
      const errorTraceId = logger.warn('Invalid authorization token', {}, traceId);
      traceId = errorTraceId;
      return new Response(
        JSON.stringify({ error: 'Unauthorized', traceId }),
        {
          status: 401,
          headers: addTraceIdToResponse({ 'Content-Type': 'application/json' }, traceId),
        }
      );
    }

    const userId = userData.user.id;
    traceId = logger.info('Exporting user data', { userId }, traceId);

    // Fetch all user data in parallel
    const [profilesRes, logsRes, commentsRes, transactionsRes, followersRes, followingRes] =
      await Promise.all([
        supabase.from('profiles').select('*').eq('id', userId),
        supabase.from('log_entries').select('*').eq('user_id', userId).order('created_at', {
          ascending: false,
        }),
        supabase.from('comments').select('*').eq('user_id', userId).order('created_at', {
          ascending: false,
        }),
        supabase
          .from('transactions')
          .select('*')
          .or(`sender_id.eq.${userId},recipient_id.eq.${userId}`)
          .order('created_at', { ascending: false }),
        supabase.from('follows').select('follower_id').eq('followee_id', userId),
        supabase.from('follows').select('followee_id').eq('follower_id', userId),
      ]);

    // Check for errors
    const errors = [profilesRes.error, logsRes.error, commentsRes.error, transactionsRes.error];
    if (errors.some((e) => e)) {
      const errorTraceId = logger.error('Failed to export user data', 'Database query failed', {
        userId,
        errors: errors.filter((e) => e).map((e) => e?.message),
      });
      traceId = errorTraceId;
      return new Response(
        JSON.stringify({ error: 'Failed to export data', traceId }),
        {
          status: 500,
          headers: addTraceIdToResponse({ 'Content-Type': 'application/json' }, traceId),
        }
      );
    }

    // Build comprehensive export
    const exportData = {
      userId,
      exportedAt: new Date().toISOString(),
      data: {
        profile: profilesRes.data?.[0] || null,
        moodLogs: logsRes.data || [],
        comments: commentsRes.data || [],
        transactions: transactionsRes.data || [],
        social: {
          followers: followersRes.data || [],
          following: followingRes.data || [],
        },
      },
      summary: {
        totalMoodLogs: logsRes.data?.length || 0,
        totalComments: commentsRes.data?.length || 0,
        totalTransactions: transactionsRes.data?.length || 0,
        followers: followersRes.data?.length || 0,
        following: followingRes.data?.length || 0,
      },
    };

    traceId = logger.info('User data exported successfully', {
      userId,
      dataSize: JSON.stringify(exportData).length,
      summary: exportData.summary,
    });

    // Return JSON file for download
    const filename = `echo-mirror-data-export-${userId}-${Date.now()}.json`;

    return new Response(JSON.stringify(exportData, null, 2), {
      status: 200,
      headers: addTraceIdToResponse(
        {
          'Content-Type': 'application/json',
          'Content-Disposition': `attachment; filename="${filename}"`,
        },
        traceId
      ),
    });
  } catch (error) {
    const errorTraceId = logger.error(
      'Unexpected error in export-user-data',
      error instanceof Error ? error : new Error(String(error)),
      {},
      traceId
    );
    traceId = errorTraceId;

    return new Response(
      JSON.stringify({ error: 'Internal server error', traceId }),
      {
        status: 500,
        headers: addTraceIdToResponse({ 'Content-Type': 'application/json' }, traceId),
      }
    );
  }
}

// Export for Supabase Edge Functions
Deno.serve(exportUserDataFunction);
