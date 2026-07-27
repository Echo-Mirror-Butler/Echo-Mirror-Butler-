/**
 * _shared/idempotency.ts
 *
 * Reusable idempotency-key helpers for Supabase Edge Functions.
 *
 * Usage (in any mutating edge function):
 *
 *   import { checkIdempotency, storeIdempotencyResult, extractIdempotencyKey }
 *     from '../_shared/idempotency.ts';
 *
 *   const idempotencyKey = extractIdempotencyKey(req);
 *
 *   if (idempotencyKey) {
 *     const cached = await checkIdempotency(supabaseAdmin, userId, 'send-echo', idempotencyKey);
 *     if (cached.hit) {
 *       return cachedJsonResponse(cached.body, cached.status);
 *     }
 *   }
 *
 *   // ... perform the mutating work ...
 *
 *   const responseBody = { success: true, ... };
 *   if (idempotencyKey) {
 *     await storeIdempotencyResult(supabaseAdmin, userId, 'send-echo', idempotencyKey, 201, responseBody);
 *   }
 *   return jsonResponse(responseBody, 201);
 *
 * Issue #639
 */

import { SupabaseClient } from 'npm:@supabase/supabase-js@2';

// ── Types ──────────────────────────────────────────────────────────────────

export type IdempotencyCacheHit = {
  hit: true;
  status: number;
  body: unknown;
};

export type IdempotencyCacheMiss = {
  hit: false;
};

export type IdempotencyCheckResult = IdempotencyCacheHit | IdempotencyCacheMiss;

// ── Constants ──────────────────────────────────────────────────────────────

/** The HTTP header clients must send to opt into idempotency. */
export const IDEMPOTENCY_KEY_HEADER = 'Idempotency-Key';

/**
 * HTTP header added to replayed responses so clients can distinguish a cached
 * reply from a fresh execution.
 */
export const IDEMPOTENCY_REPLAYED_HEADER = 'Idempotency-Replayed';

// ── Helpers ────────────────────────────────────────────────────────────────

/**
 * Extracts and trims the idempotency key from the request header.
 * Returns `null` when the header is absent or empty, meaning the request
 * is processed without deduplication (backward-compatible).
 */
export function extractIdempotencyKey(req: Request): string | null {
  const raw = req.headers.get(IDEMPOTENCY_KEY_HEADER);
  if (!raw) return null;
  const trimmed = raw.trim();
  if (trimmed.length === 0 || trimmed.length > 255) return null;
  return trimmed;
}

/**
 * Looks up an idempotency key in the database.
 *
 * @param supabaseAdmin - Admin client (bypasses RLS).
 * @param userId        - The authenticated user's UUID.
 * @param functionName  - Name of the edge function (e.g. 'send-echo').
 * @param key           - The client-supplied idempotency key.
 *
 * @returns `{ hit: true, status, body }` when a non-expired cached result is
 *          found, or `{ hit: false }` otherwise.
 */
export async function checkIdempotency(
  supabaseAdmin: SupabaseClient,
  userId: string,
  functionName: string,
  key: string,
): Promise<IdempotencyCheckResult> {
  const { data, error } = await supabaseAdmin
    .from('idempotency_keys')
    .select('response_status, response_body, expires_at')
    .eq('user_id', userId)
    .eq('function_name', functionName)
    .eq('idempotency_key', key)
    .maybeSingle();

  if (error) {
    // Log but don't hard-fail; fall through to normal processing.
    console.error(
      `[idempotency] DB lookup error for key=${key} fn=${functionName}:`,
      error.message,
    );
    return { hit: false };
  }

  if (!data) {
    return { hit: false };
  }

  // Treat expired rows as a miss (the cleanup job will remove them later)
  if (new Date(data.expires_at) <= new Date()) {
    return { hit: false };
  }

  return {
    hit: true,
    status: data.response_status as number,
    body: data.response_body as unknown,
  };
}

/**
 * Persists the result of a successful (or deterministic client-error) request
 * so future duplicate requests with the same key receive the cached response.
 *
 * **Do NOT call this for transient 5xx failures** — those should remain
 * retriable so the client can get a fresh attempt.
 *
 * @param supabaseAdmin - Admin client (bypasses RLS).
 * @param userId        - The authenticated user's UUID.
 * @param functionName  - Name of the edge function (e.g. 'send-echo').
 * @param key           - The client-supplied idempotency key.
 * @param status        - HTTP status of the response being stored.
 * @param body          - JSON-serialisable response body being stored.
 */
export async function storeIdempotencyResult(
  supabaseAdmin: SupabaseClient,
  userId: string,
  functionName: string,
  key: string,
  status: number,
  body: unknown,
): Promise<void> {
  const { error } = await supabaseAdmin.from('idempotency_keys').insert({
    user_id: userId,
    function_name: functionName,
    idempotency_key: key,
    response_status: status,
    response_body: body,
    // expires_at defaults to now() + 24 hours in the DB
  });

  if (error) {
    // A unique-constraint violation means another concurrent request raced us
    // to store the same key — that is fine; both callers will return the same
    // logical result, and the first insert wins.
    if (error.code === '23505') {
      console.warn(
        `[idempotency] Concurrent insert race for key=${key} fn=${functionName} — this is safe to ignore.`,
      );
      return;
    }

    // Any other error: log and continue. Failing to store the key means the
    // NEXT duplicate request will re-execute, which is the safe fallback.
    console.error(
      `[idempotency] Failed to store result for key=${key} fn=${functionName}:`,
      error.message,
    );
  }
}

/**
 * Builds a Response from a cached idempotency hit, appending the
 * `Idempotency-Replayed: true` header so clients can detect replays.
 */
export function buildReplayedResponse(
  body: unknown,
  status: number,
  extraHeaders: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      [IDEMPOTENCY_REPLAYED_HEADER]: 'true',
      ...extraHeaders,
    },
  });
}
