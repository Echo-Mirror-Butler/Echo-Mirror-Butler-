/**
 * get-agora-credentials — Supabase Edge Function
 *
 * Issue #761: this function used to mint a live Agora RTC **publisher** token,
 * valid for 24 hours, for whatever `sessionId`/`userId` pair arrived in the
 * request body — with no authentication at all. Anyone who could reach the URL
 * and knew (or guessed) a `sessionId` could join a private call able to
 * broadcast and receive, for a day.
 *
 * It now:
 *   1. requires a valid `Authorization: Bearer <jwt>` (401 otherwise) and
 *      resolves the caller through `supabase.auth.getUser()`;
 *   2. refuses unknown, inactive or expired sessions before minting anything;
 *   3. mints the token for a **server-derived** uid (`deriveAgoraUid`) instead of
 *      an identity the client asked for, and returns that uid so the client
 *      joins as the same account the token was issued to;
 *   4. keeps the lifetime at two hours by default — matching the session's own
 *      default expiry — instead of 24, and never past the session expiry.
 *
 * Per-user call membership is not modelled in the database today: there is no
 * participants table, and joining only bumps `video_sessions.participant_count`
 * through an RPC that runs with the anon key, so it cannot attribute a user.
 * Session-level authorisation is therefore "authenticated caller + existing,
 * joinable session". A membership table would let this tighten further; the
 * pull request says so explicitly rather than pretending otherwise.
 *
 * POST /get-agora-credentials
 * Headers: Authorization: Bearer <supabase user access token>
 * Body:    { sessionId: string, userId?: string }  (userId is no longer trusted)
 * Returns: { token, appId, uid, expiresAt }
 */

// deno-lint-ignore-file no-import-prefix
import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { RtcRole, RtcTokenBuilder } from "npm:agora-access-token@2.0.1";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  addTraceIdToResponse,
  createLogger,
  extractTraceId,
} from "../_shared/logger.ts";

const logger = createLogger("get-agora-credentials");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

/** Two hours — the same default lifetime `video_sessions.expires_at` uses. */
export const DEFAULT_TOKEN_TTL_SECONDS = 2 * 60 * 60;
/** Upper bound, so a misconfigured environment cannot mint a day-long token. */
export const MAX_TOKEN_TTL_SECONDS = 6 * 60 * 60;

export interface EnvLike {
  get(key: string): string | undefined;
}

/**
 * Lifetime of a minted token. `AGORA_TOKEN_TTL_SECONDS` may change it, but never
 * above `MAX_TOKEN_TTL_SECONDS` or below a minute.
 */
export function resolveTokenTtlSeconds(env: EnvLike = Deno.env): number {
  const raw = env.get("AGORA_TOKEN_TTL_SECONDS");
  const parsed = raw ? Number.parseInt(raw, 10) : Number.NaN;
  if (!Number.isFinite(parsed) || parsed <= 0) return DEFAULT_TOKEN_TTL_SECONDS;
  return Math.min(Math.max(parsed, 60), MAX_TOKEN_TTL_SECONDS);
}

/**
 * Deterministic Agora uid for a Supabase user. Agora needs a 32-bit unsigned
 * integer, so the id is hashed and truncated; the sign bit is dropped and 0
 * (which Agora reads as "any account") is never produced.
 */
export function deriveAgoraUid(userId: string): number {
  const bytes = new TextEncoder().encode(`agora-uid:${userId}`);
  let hash = 0x811c9dc5;
  for (const byte of bytes) {
    hash ^= byte;
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  const uid = hash >>> 1;
  return uid === 0 ? 1 : uid;
}

/** Epoch seconds at which a session stops being joinable, or null if unknown. */
export function sessionExpirySeconds(
  session: { expires_at?: unknown },
): number | null {
  const value = session?.expires_at;
  if (typeof value !== "string") return null;
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? Math.floor(parsed / 1000) : null;
}

function json(body: unknown, status: number, traceId?: string): Response {
  const headers = traceId
    ? addTraceIdToResponse({
      ...corsHeaders,
      "Content-Type": "application/json",
    }, traceId)
    : { ...corsHeaders, "Content-Type": "application/json" };
  return new Response(JSON.stringify(body), { status, headers });
}

export async function getAgoraCredentialsFunction(
  req: Request,
  injectedClient?: unknown,
): Promise<Response> {
  let traceId = extractTraceId(Object.fromEntries(req.headers)) ?? "";

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    traceId = logger.warn(
      "Invalid request method",
      { method: req.method },
      traceId,
    );
    return json({ error: "Method not allowed", traceId }, 405, traceId);
  }

  try {
    // ── 1. The caller must be authenticated ────────────────────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      traceId = logger.warn("Missing authorization header", {}, traceId);
      return json(
        { error: "Unauthorized", message: "Authentication required", traceId },
        401,
        traceId,
      );
    }

    // deno-lint-ignore no-explicit-any
    let body: any;
    try {
      body = await req.json();
    } catch {
      traceId = logger.warn("Invalid JSON body", {}, traceId);
      return json({ error: "Invalid JSON body", traceId }, 400, traceId);
    }

    const sessionId = typeof body?.sessionId === "string"
      ? body.sessionId.trim()
      : "";
    if (!sessionId) {
      traceId = logger.warn("Missing sessionId", {}, traceId);
      return json({ error: "sessionId is required", traceId }, 400, traceId);
    }

    // deno-lint-ignore no-explicit-any
    let supabase: any = injectedClient;
    if (!supabase) {
      const supabaseUrl = Deno.env.get("SUPABASE_URL");
      const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
      if (!supabaseUrl || !supabaseKey) {
        traceId = logger.error(
          "Missing Supabase credentials",
          "Configuration error",
          {},
          traceId,
        );
        return json(
          { error: "Server configuration error", traceId },
          500,
          traceId,
        );
      }
      supabase = createClient(supabaseUrl, supabaseKey);
    }

    const { data: userData, error: authError } = await supabase.auth.getUser(
      authHeader.slice(7),
    );
    if (authError || !userData?.user) {
      traceId = logger.warn("Invalid authorization token", {
        error: authError?.message,
      }, traceId);
      return json(
        {
          error: "Unauthorized",
          message: "Invalid or expired session",
          traceId,
        },
        401,
        traceId,
      );
    }

    const callerId: string = userData.user.id;

    // ── 2. The session must exist and be joinable ──────────────────────────
    const { data: session, error: sessionError } = await supabase
      .from("video_sessions")
      .select("id, host_id, is_active, expires_at")
      .eq("id", sessionId)
      .single();

    if (sessionError && sessionError.code !== "PGRST116") {
      traceId = logger.error("Failed to load session", sessionError, {
        sessionId,
      }, traceId);
      return json({ error: "Failed to load session", traceId }, 500, traceId);
    }

    if (!session) {
      traceId = logger.warn("Session not found", { sessionId }, traceId);
      return json({ error: "Session not found", traceId }, 404, traceId);
    }

    const nowSeconds = Math.floor(Date.now() / 1000);
    const expiresAt = sessionExpirySeconds(session);

    if (
      session.is_active !== true ||
      (expiresAt !== null && expiresAt <= nowSeconds)
    ) {
      traceId = logger.warn(
        "Session is not joinable",
        { sessionId, isActive: session.is_active, expiresAt },
        traceId,
      );
      return json(
        { error: "Forbidden", message: "Session is not available", traceId },
        403,
        traceId,
      );
    }

    // ── 3. Minting needs the Agora credentials ─────────────────────────────
    // Checked here rather than first, so a misconfigured environment cannot
    // mask a 401/403/404 with a 500.
    const appId = Deno.env.get("AGORA_APP_ID");
    const appCert = Deno.env.get("AGORA_APP_CERT");
    if (!appId || !appCert) {
      traceId = logger.error(
        "Agora credentials not configured",
        "Configuration error",
        {},
        traceId,
      );
      return json(
        { error: "Server configuration error", traceId },
        500,
        traceId,
      );
    }

    // ── 4. Mint for the caller's derived identity, not a claimed one ────────
    const uid = deriveAgoraUid(callerId);
    const requestedUid = body?.userId === undefined || body?.userId === null
      ? null
      : String(body.userId);

    if (requestedUid !== null && requestedUid !== String(uid)) {
      // Not an error: older builds send their own numeric id. The token below
      // and the returned `uid` are the identity the client must use.
      traceId = logger.info(
        "Ignoring client-supplied uid in favour of the derived one",
        { requestedUid, uid },
        traceId,
      );
    }

    // A token may never outlive the session it belongs to.
    const privilegeExpiredTs = Math.min(
      nowSeconds + resolveTokenTtlSeconds(),
      expiresAt ?? Number.POSITIVE_INFINITY,
    );

    const token = RtcTokenBuilder.buildTokenWithAccount(
      appId,
      appCert,
      sessionId,
      String(uid),
      RtcRole.PUBLISHER,
      privilegeExpiredTs,
    );

    traceId = logger.info(
      "Agora token issued",
      {
        sessionId,
        uid,
        expiresAt: privilegeExpiredTs,
        isHost: session.host_id === callerId,
      },
      traceId,
    );

    return json(
      { token, appId, uid, expiresAt: privilegeExpiredTs },
      200,
      traceId,
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    traceId = logger.error("Unhandled error", message, {}, traceId);
    return json({ error: message, traceId }, 500, traceId);
  }
}

serve(getAgoraCredentialsFunction);
