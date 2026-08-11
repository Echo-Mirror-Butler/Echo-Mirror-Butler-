/**
 * Issue #592: Account Deletion Flow - Scheduled Hard Delete Job
 *
 * This scheduled function runs daily (via Supabase pg_cron) to permanently delete
 * accounts whose grace period has expired.
 *
 * Grace period: 14 days from soft deletion
 * This function is called: pg_cron scheduled daily at 2 AM
 *
 * Important: Ensures CASCADE deletes are set up correctly in migrations
 * to remove: mood logs, comments, transactions, social connections, etc.
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { createLogger } from '../_shared/logger.ts';

const logger = createLogger('hard-delete-accounts');

export async function hardDeleteExpiredAccounts(): Promise<void> {
  const traceId = logger.info('Starting scheduled hard-delete job', {
    scheduledTime: new Date().toISOString(),
  });

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!supabaseUrl || !supabaseKey) {
      logger.error('Missing Supabase credentials', 'Configuration error', {}, traceId);
      return;
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    // Find all accounts where grace period has expired
    const now = new Date().toISOString();
    const { data: expiredAccounts, error: selectError } = await supabase
      .from('auth.users')
      .select('id, email')
      .eq('soft_deleted_at', true) // soft_deleted_at is not null
      .lt('deleted_at', now) // deleted_at is in the past
      .limit(100); // Process in batches to avoid timeouts

    if (selectError) {
      logger.error('Failed to query expired accounts', selectError, { error: selectError.message }, traceId);
      return;
    }

    if (!expiredAccounts || expiredAccounts.length === 0) {
      logger.info('No accounts ready for hard deletion', {}, traceId);
      return;
    }

    logger.info('Found expired accounts to delete', {
      count: expiredAccounts.length,
      now,
    });

    // Hard delete each account (this cascades to related records)
    let deletedCount = 0;
    let failedCount = 0;

    for (const account of expiredAccounts) {
      try {
        // Delete from auth.users (cascade should handle related records)
        const { error: deleteError } = await supabase.auth.admin.deleteUser(account.id);

        if (deleteError) {
          logger.warn('Failed to delete account', {
            userId: account.id,
            email: account.email,
            error: deleteError.message,
          });
          failedCount++;
        } else {
          logger.info('Hard-deleted account', {
            userId: account.id,
            email: account.email,
          });
          deletedCount++;
        }
      } catch (error) {
        logger.error(
          'Error deleting account',
          error instanceof Error ? error : new Error(String(error)),
          { userId: account.id },
          traceId
        );
        failedCount++;
      }
    }

    logger.info('Hard-delete job completed', {
      totalProcessed: expiredAccounts.length,
      successfulDeletes: deletedCount,
      failedDeletes: failedCount,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error(
      'Unexpected error in hard-delete-accounts',
      error instanceof Error ? error : new Error(String(error)),
      {},
      traceId
    );
  }
}

// For local testing or manual triggering
export async function handleRequest(req: Request): Promise<Response> {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405 });
  }

  try {
    await hardDeleteExpiredAccounts();
    return new Response(
      JSON.stringify({ success: true, message: 'Hard-delete job executed' }),
      { status: 200 }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: 'Job failed', details: String(error) }),
      { status: 500 }
    );
  }
}

// Export for Supabase Edge Functions
Deno.serve(handleRequest);

// For pg_cron scheduling:
// SELECT cron.schedule(
//   'hard-delete-expired-accounts',
//   '0 2 * * *',  -- Daily at 2 AM
//   $$SELECT net.http_post('https://[project].supabase.co/functions/v1/hard-delete-accounts',
//     json_build_object('key', '...')
//   ) $$
// );
