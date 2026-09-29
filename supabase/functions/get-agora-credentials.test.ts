/**
 * Tests for get-agora-credentials (Issue #761).
 *
 * The bug being pinned down: the function used to mint a 24-hour publisher
 * token for any `sessionId`/`userId` pair, with no authentication whatsoever.
 *
 * Run: deno test --allow-all supabase/functions/test_runner.ts
 */

// deno-lint-ignore-file no-import-prefix
import {
  assertEquals,
  assertNotEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.192.0/testing/asserts.ts";
import {
  DEFAULT_TOKEN_TTL_SECONDS,
  deriveAgoraUid,
  getAgoraCredentialsFunction,
  MAX_TOKEN_TTL_SECONDS,
  resolveTokenTtlSeconds,
  sessionExpirySeconds,
} from "./get-agora-credentials/index.ts";
import {
  createMockRequest,
  createMockSupabaseClient,
  getResponseBody,
} from "./_shared/testing.ts";

const SESSION_ID = "11111111-2222-3333-4444-555555555555";
const HOST_ID = "host-user-id";
const CALLER_ID = "test-user-id"; // the mock client's resolved user

function activeSession(overrides: Record<string, unknown> = {}) {
  return {
    id: SESSION_ID,
    host_id: HOST_ID,
    is_active: true,
    expires_at: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
    ...overrides,
  };
}

function clientWith(session: unknown) {
  return createMockSupabaseClient({
    user: { id: CALLER_ID, email: "caller@example.com" },
    tableData: { video_sessions: session ? [session] : [] },
  });
}

/** Agora env is required for the success path; restored after each test. */
async function withAgoraEnv<T>(fn: () => Promise<T>): Promise<T> {
  const previousAppId = Deno.env.get("AGORA_APP_ID");
  const previousCert = Deno.env.get("AGORA_APP_CERT");
  Deno.env.set("AGORA_APP_ID", "test-app-id");
  Deno.env.set("AGORA_APP_CERT", "test-app-certificate");
  try {
    return await fn();
  } finally {
    if (previousAppId === undefined) Deno.env.delete("AGORA_APP_ID");
    else Deno.env.set("AGORA_APP_ID", previousAppId);
    if (previousCert === undefined) Deno.env.delete("AGORA_APP_CERT");
    else Deno.env.set("AGORA_APP_CERT", previousCert);
  }
}

// ─── Authentication (the actual regression) ─────────────────────────────────

Deno.test("get-agora-credentials: handles OPTIONS preflight", async () => {
  const res = await getAgoraCredentialsFunction(createMockRequest("OPTIONS"));
  assertEquals(res.status, 200);
});

Deno.test("get-agora-credentials: rejects non-POST methods with 405", async () => {
  const res = await getAgoraCredentialsFunction(createMockRequest("GET"));
  assertEquals(res.status, 405);
});

Deno.test("get-agora-credentials: rejects a request without an Authorization header (401)", async () => {
  const req = createMockRequest("POST", { sessionId: SESSION_ID, userId: "1" });
  const res = await getAgoraCredentialsFunction(
    req,
    clientWith(activeSession()),
  );

  assertEquals(res.status, 401);
  const body = await getResponseBody(res);
  assertEquals(body.error, "Unauthorized");
  // The regression: no token may exist in this response.
  assertEquals(body.token, undefined);
});

Deno.test("get-agora-credentials: rejects a malformed Authorization header (401)", async () => {
  const req = createMockRequest(
    "POST",
    { sessionId: SESSION_ID },
    { Authorization: "Basic abc123" },
  );
  const res = await getAgoraCredentialsFunction(
    req,
    clientWith(activeSession()),
  );
  assertEquals(res.status, 401);
});

Deno.test("get-agora-credentials: rejects an invalid or expired token (401)", async () => {
  const client = createMockSupabaseClient({
    authError: new Error("Token expired"),
  });
  const req = createMockRequest(
    "POST",
    { sessionId: SESSION_ID },
    { Authorization: "Bearer expired-token" },
  );
  const res = await getAgoraCredentialsFunction(req, client);

  assertEquals(res.status, 401);
  const body = await getResponseBody(res);
  assertStringIncludes(body.message, "Invalid or expired");
});

Deno.test("get-agora-credentials: requires a sessionId (400)", async () => {
  const req = createMockRequest("POST", {}, {
    Authorization: "Bearer valid-token",
  });
  const res = await getAgoraCredentialsFunction(
    req,
    clientWith(activeSession()),
  );
  assertEquals(res.status, 400);
});

Deno.test("get-agora-credentials: rejects an unknown session before minting (404)", async () => {
  const req = createMockRequest(
    "POST",
    { sessionId: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee" },
    { Authorization: "Bearer valid-token" },
  );
  const res = await getAgoraCredentialsFunction(req, clientWith(null));

  assertEquals(res.status, 404);
  const body = await getResponseBody(res);
  assertEquals(body.token, undefined);
});

Deno.test("get-agora-credentials: rejects an inactive session (403)", async () => {
  const req = createMockRequest(
    "POST",
    { sessionId: SESSION_ID },
    { Authorization: "Bearer valid-token" },
  );
  const res = await getAgoraCredentialsFunction(
    req,
    clientWith(activeSession({ is_active: false })),
  );

  assertEquals(res.status, 403);
  const body = await getResponseBody(res);
  assertEquals(body.token, undefined);
});

Deno.test("get-agora-credentials: rejects an expired session (403)", async () => {
  const req = createMockRequest(
    "POST",
    { sessionId: SESSION_ID },
    { Authorization: "Bearer valid-token" },
  );
  const expired = activeSession({
    expires_at: new Date(Date.now() - 60_000).toISOString(),
  });
  const res = await getAgoraCredentialsFunction(req, clientWith(expired));

  assertEquals(res.status, 403);
  assertEquals((await getResponseBody(res)).token, undefined);
});

// ─── Success path ───────────────────────────────────────────────────────────

Deno.test("get-agora-credentials: an authenticated caller joining an active session gets a token", async () => {
  await withAgoraEnv(async () => {
    const req = createMockRequest(
      "POST",
      { sessionId: SESSION_ID, userId: "4242" },
      { Authorization: "Bearer valid-token" },
    );
    const res = await getAgoraCredentialsFunction(
      req,
      clientWith(activeSession()),
    );

    assertEquals(res.status, 200);
    const body = await getResponseBody(res);
    assertEquals(typeof body.token, "string");
    assertEquals(body.token.length > 0, true);
    assertEquals(body.appId, "test-app-id");
    // The uid is derived from the authenticated user, not from the body.
    assertEquals(body.uid, deriveAgoraUid(CALLER_ID));
    assertNotEquals(body.uid, 4242);
    assertEquals(typeof body.expiresAt, "number");
  });
});

Deno.test("get-agora-credentials: a token never outlives its session", async () => {
  await withAgoraEnv(async () => {
    const sessionExpiry = Math.floor(Date.now() / 1000) + 120; // two minutes
    const session = activeSession({
      expires_at: new Date(sessionExpiry * 1000).toISOString(),
    });

    const req = createMockRequest(
      "POST",
      { sessionId: SESSION_ID },
      { Authorization: "Bearer valid-token" },
    );
    const res = await getAgoraCredentialsFunction(req, clientWith(session));
    const body = await getResponseBody(res);

    assertEquals(res.status, 200);
    assertEquals(body.expiresAt <= sessionExpiry, true);
    assertEquals(body.expiresAt > Math.floor(Date.now() / 1000), true);
  });
});

// ─── Helpers ────────────────────────────────────────────────────────────────

Deno.test("deriveAgoraUid: deterministic, distinct per user, never zero", () => {
  const first = deriveAgoraUid("user-1");

  assertEquals(deriveAgoraUid("user-1"), first);
  assertNotEquals(deriveAgoraUid("user-2"), first);
  assertEquals(first > 0, true);
  assertEquals(first <= 0x7fffffff, true); // Agora wants a 32-bit int
});

Deno.test("resolveTokenTtlSeconds: two hours by default, clamped when configured", () => {
  assertEquals(
    resolveTokenTtlSeconds({ get: () => undefined }),
    DEFAULT_TOKEN_TTL_SECONDS,
  );
  assertEquals(
    resolveTokenTtlSeconds({ get: () => "not-a-number" }),
    DEFAULT_TOKEN_TTL_SECONDS,
  );
  assertEquals(resolveTokenTtlSeconds({ get: () => "600" }), 600);
  assertEquals(resolveTokenTtlSeconds({ get: () => "5" }), 60); // floor
  assertEquals(
    resolveTokenTtlSeconds({ get: () => String(MAX_TOKEN_TTL_SECONDS * 10) }),
    MAX_TOKEN_TTL_SECONDS,
  );
  assertEquals(DEFAULT_TOKEN_TTL_SECONDS, 7200);
});

Deno.test("sessionExpirySeconds: parses ISO timestamps and ignores junk", () => {
  const iso = "2026-09-30T12:00:00.000Z";
  assertEquals(
    sessionExpirySeconds({ expires_at: iso }),
    Math.floor(Date.parse(iso) / 1000),
  );
  assertEquals(sessionExpirySeconds({ expires_at: "not-a-date" }), null);
  assertEquals(sessionExpirySeconds({}), null);
});
