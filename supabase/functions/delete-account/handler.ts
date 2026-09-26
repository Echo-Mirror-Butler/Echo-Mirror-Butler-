/**
 * Request handler for `delete-account`, separated from `index.ts` so it can be
 * called without starting a server, with the Supabase client, logger and clock
 * injected (issue #735).
 */

import { createLogger, extractTraceId, addTraceIdToResponse } from "../_shared/logger.ts";

const GRACE_PERIOD_DAYS = 14;
const CONFIRMATION_PHRASE = "DELETE MY ACCOUNT"; // User must type this exactly

/** Minimal shape of the Supabase client the handler uses. */
export interface DeleteAccountSupabase {
  from: (table: string) => {
    update: (values: Record<string, unknown>) => {
      eq: (column: string, value: unknown) => PromiseLike<{ error: { message: string } | null }>;
    };
  };
}

export interface DeleteAccountDeps {
  /** The service-role client; `null` stands for a misconfigured runtime. */
  supabase: DeleteAccountSupabase | null;
  logger: ReturnType<typeof createLogger>;
  /** Injectable clock so tests pin the grace-period dates. */
  now?: () => Date;
}

function jsonError(error: string, traceId: string, status: number): Response {
  return new Response(
    JSON.stringify({ error, traceId }),
    {
      status,
      headers: addTraceIdToResponse({ "Content-Type": "application/json" }, traceId),
    },
  );
}

export async function handleRequest(req: Request, deps: DeleteAccountDeps): Promise<Response> {
  const logger = deps.logger;
  const incomingTraceId = extractTraceId(Object.fromEntries(req.headers));
  let traceId = incomingTraceId;

  try {
    // Preflight for browsers calling the function cross-origin.
    if (req.method === "OPTIONS") {
      return new Response("ok", {
        status: 200,
        headers: addTraceIdToResponse(
          {
            "Content-Type": "text/plain",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
            "Access-Control-Allow-Methods": "POST, OPTIONS",
          },
          traceId ?? "unknown",
        ),
      });
    }

    if (req.method !== "POST") {
      const errorTraceId = logger.warn("Invalid request method", { method: req.method }, traceId);
      traceId = errorTraceId;
      return jsonError("Method not allowed", traceId, 405);
    }

    // Parse request body — malformed JSON is a client error (400), not a
    // server error, so it must not fall through to the 500 catch-all.
    let body: { userId?: unknown; confirmationPhrase?: unknown };
    try {
      body = await req.json();
    } catch {
      const errorTraceId = logger.warn("Malformed JSON body", undefined, traceId);
      traceId = errorTraceId;
      return jsonError("Invalid JSON body", traceId, 400);
    }

    const userId = body.userId;
    const confirmationPhrase = body.confirmationPhrase;

    traceId = logger.info("Delete account request received", { userId }, traceId);

    if (typeof userId !== "string" || userId.length === 0) {
      const errorTraceId = logger.warn("Invalid userId", { userId }, traceId);
      traceId = errorTraceId;
      return jsonError("Invalid userId", traceId, 400);
    }

    if (confirmationPhrase !== CONFIRMATION_PHRASE) {
      const errorTraceId = logger.warn("Invalid confirmation phrase", { userId }, traceId);
      traceId = errorTraceId;
      return jsonError("Invalid confirmation phrase", traceId, 400);
    }

    const supabase = deps.supabase;
    if (!supabase) {
      const errorTraceId = logger.error("Missing Supabase credentials", "Configuration error", {}, traceId);
      traceId = errorTraceId;
      return jsonError("Server configuration error", traceId, 500);
    }

    const now = deps.now ?? (() => new Date());
    const gracePeriodEndsAt = now();
    gracePeriodEndsAt.setDate(gracePeriodEndsAt.getDate() + GRACE_PERIOD_DAYS);

    traceId = logger.info(
      "Soft-deleting account",
      { userId, gracePeriodEndsAt: gracePeriodEndsAt.toISOString() },
      traceId,
    );

    // Soft-delete: Mark account as deleted but keep data
    const { error: updateError } = await supabase
      .from("auth.users")
      .update({
        soft_deleted_at: now().toISOString(),
        deleted_at: gracePeriodEndsAt.toISOString(),
        email: `deleted-${userId}@deleted.local`, // Anonymize email
      })
      .eq("id", userId);

    if (updateError) {
      const errorTraceId = logger.error("Failed to soft-delete account", updateError, { userId }, traceId);
      traceId = errorTraceId;
      return jsonError("Failed to delete account", traceId, 500);
    }

    // Hide user data from feeds immediately. A failure here previously only
    // logged a warning and still returned success, leaving the account
    // soft-deleted with its posts still visible — reporting an error the
    // client can retry on is safer (every step is idempotent).
    const { error: hideError } = await supabase.from("profiles").update({ hidden: true }).eq("id", userId);

    if (hideError) {
      const errorTraceId = logger.error("Could not hide profile", hideError, { userId }, traceId);
      traceId = errorTraceId;
      return jsonError("Failed to hide profile data", traceId, 500);
    }

    // Log successful soft-deletion
    const successTraceId = logger.info(
      "Account soft-deleted successfully",
      {
        userId,
        gracePeriodEndsAt: gracePeriodEndsAt.toISOString(),
        canRecoverUntil: gracePeriodEndsAt.toISOString(),
      },
      traceId,
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
        headers: addTraceIdToResponse({ "Content-Type": "application/json" }, traceId),
      },
    );
  } catch (error) {
    const errorTraceId = logger.error(
      "Unexpected error in delete-account",
      error instanceof Error ? error : new Error(String(error)),
      {},
      traceId,
    );
    traceId = errorTraceId;

    return jsonError("Internal server error", traceId, 500);
  }
}
