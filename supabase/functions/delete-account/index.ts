/**
 * Issue #592: Account Deletion Flow - Soft Delete Function
 *
 * This Edge Function handles the soft deletion of user accounts.
 * Soft-deleted accounts are flagged in the database but not permanently removed.
 * After a grace period (14 days), a scheduled job performs hard deletion.
 *
 * POST /delete-account
 * Request body: { userId: string, confirmationPhrase: string }
 * Response: { success: boolean, traceId: string, gracePeriodEndsAt: string }
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { createLogger, extractTraceId, addTraceIdToResponse } from '../_shared/logger.ts';

const logger = createLogger('delete-account');
const GRACE_PERIOD_DAYS = 14;
const CONFIRMATION_PHRASE = 'DELETE MY ACCOUNT'; // User must type this exactly

export async function deleteAccountFunction(req: Request): Promise<Response> {
  // Extract trace ID from incoming request
  const incomingTraceId = extractTraceId(Object.fromEntries(req.headers));
  let traceId = incomingTraceId;

  try {
    // Verify request method
    if (req.method !== 'POST') {
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

    // Parse request body
    const { userId, confirmationPhrase } = await req.json();

    traceId = logger.info('Delete account request received', { userId }, traceId);

    // Validation
    if (!userId || typeof userId !== 'string') {
      const errorTraceId = logger.warn('Invalid userId', { userId }, traceId);
      traceId = errorTraceId;
      return new Response(
        JSON.stringify({ error: 'Invalid userId', traceId }),
        {
          status: 400,
          headers: addTraceIdToResponse({ 'Content-Type': 'application/json' }, traceId),
        }
      );
    }

    if (confirmationPhrase !== CONFIRMATION_PHRASE) {
      const errorTraceId = logger.warn('Invalid confirmation phrase', { userId }, traceId);
      traceId = errorTraceId;
      return new Response(
        JSON.stringify({ error: 'Invalid confirmation phrase', traceId }),
        {
          status: 400,
          headers: addTraceIdToResponse({ 'Content-Type': 'application/json' }, traceId),
        }
      );
    }

    // Initialize Supabase client
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
        {
          status: 500,
          headers: addTraceIdToResponse({ 'Content-Type': 'application/json' }, traceId),
        }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    // Calculate grace period end date
    const gracePeriodEndsAt = new Date();
    gracePeriodEndsAt.setDate(gracePeriodEndsAt.getDate() + GRACE_PERIOD_DAYS);

    traceId = logger.info(
      'Soft-deleting account',
      { userId, gracePeriodEndsAt: gracePeriodEndsAt.toISOString() },
      traceId
    );

    // Soft-delete: Mark account as deleted but keep data
    const { error: updateError } = await supabase
      .from('auth.users')
      .update({
        soft_deleted_at: new Date().toISOString(),
        deleted_at: gracePeriodEndsAt.toISOString(),
        email: `deleted-${userId}@deleted.local`, // Anonymize email
      })
      .eq('id', userId);

    if (updateError) {
      const errorTraceId = logger.error(
        'Failed to soft-delete account',
        updateError,
        { userId },
        traceId
      );
      traceId = errorTraceId;
      return new Response(
        JSON.stringify({ error: 'Failed to delete account', traceId }),
        {
          status: 500,
          headers: addTraceIdToResponse({ 'Content-Type': 'application/json' }, traceId),
        }
      );
    }

    // Hide user data from feeds immediately
    const { error: hideError } = await supabase.from('profiles').update({ hidden: true }).eq('id', userId);

    if (hideError) {
      logger.warn('Could not hide profile', { userId, error: hideError.message }, traceId);
    }

    // Log successful soft-deletion
    const successTraceId = logger.info(
      'Account soft-deleted successfully',
      {
        userId,
        gracePeriodEndsAt: gracePeriodEndsAt.toISOString(),
        canRecoverUntil: gracePeriodEndsAt.toISOString(),
      },
      traceId
    );
    traceId = successTraceId;

    return new Response(
      JSON.stringify({
        success: true,
        traceId,
        message: `Account scheduled for deletion on ${gracePeriodEndsAt.toLocaleDateString()}`,
        gracePeriodEndsAt: gracePeriodEndsAt.toISOString(),
        canRecoverUntil: gracePeriodEndsAt.toISOString(),
      }),
      {
        status: 200,
        headers: addTraceIdToResponse(
          {
            'Content-Type': 'application/json',
          },
          traceId
        ),
      }
    );
  } catch (error) {
    const errorTraceId = logger.error(
      'Unexpected error in delete-account',
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
Deno.serve(deleteAccountFunction);
