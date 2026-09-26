import { assertEquals, assert } from "https://deno.land/std@0.192.0/testing/asserts.ts";
import { handleRequest } from "./handler.ts";
import { createLogger } from "../_shared/logger.ts";
import { fakeSupabase, jsonRequest, malformedJsonRequest, optionsRequest } from "../_shared/testing.ts";

const USER = "11111111-2222-3333-4444-555555555555";
const PHRASE = "DELETE MY ACCOUNT";
const PINNED_NOW = new Date("2026-09-26T12:00:00.000Z");
const TOKEN = "valid.jwt.token";

function build(script: Parameters<typeof fakeSupabase>[0] = {}, supabase: unknown | null = undefined) {
  const db = fakeSupabase(script);
  const client = supabase === undefined ? db.client : supabase;
  const deps = {
    supabase: client as never,
    logger: createLogger("delete-account"),
    now: () => new Date(PINNED_NOW),
    // Default fake auth: only the good token resolves to USER.
    getUser: async (token: string) =>
      token === TOKEN ? { user: { id: USER } } : { user: null, error: { message: "invalid token" } },
  };
  return { db, deps };
}

function deleteReq(
  body: unknown,
  headers: Record<string, string> = { Authorization: `Bearer ${TOKEN}` },
): Request {
  return jsonRequest(body, { headers });
}

Deno.test("OPTIONS preflight answers 200 with CORS headers", async () => {
  const { deps } = build();
  const res = await handleRequest(optionsRequest(), deps);
  assertEquals(res.status, 200);
  assertEquals(res.headers.get("Access-Control-Allow-Origin"), "*");
  assert(res.headers.get("Access-Control-Allow-Methods")!.includes("POST"));
});

Deno.test("a non-POST method is refused with 405 and nothing is written", async () => {
  const { deps, db } = build();
  const res = await handleRequest(jsonRequest(undefined, { method: "GET" }), deps);
  assertEquals(res.status, 405);
  const payload = await res.json();
  assertEquals(payload.error, "Method not allowed");
  assert(typeof payload.traceId === "string" && payload.traceId.length > 0);
  assertEquals(db.calls.update.length, 0);
});

Deno.test("malformed JSON is a 400 client error, not a 500", async () => {
  const { deps, db } = build();
  const res = await handleRequest(malformedJsonRequest(), deps);
  assertEquals(res.status, 400);
  const payload = await res.json();
  assertEquals(payload.error, "Invalid JSON body");
  assertEquals(db.calls.update.length, 0);
});

Deno.test("a missing userId is rejected with 400 before touching the database", async () => {
  const { deps, db } = build({ update: [{ error: null }] });
  const res = await handleRequest(deleteReq({ confirmationPhrase: PHRASE }), deps);
  assertEquals(res.status, 400);
  const payload = await res.json();
  assertEquals(payload.error, "Invalid userId");
  assertEquals(db.calls.update.length, 0);
});

Deno.test("a non-string userId is rejected with 400", async () => {
  const { deps, db } = build({ update: [{ error: null }] });
  const res = await handleRequest(deleteReq({ userId: 42, confirmationPhrase: PHRASE }), deps);
  assertEquals(res.status, 400);
  assertEquals((await res.json()).error, "Invalid userId");
  assertEquals(db.calls.update.length, 0);
});

Deno.test("a wrong confirmation phrase is rejected with 400 and no database write", async () => {
  const { deps, db } = build({ update: [{ error: null }] });
  const res = await handleRequest(deleteReq({ userId: USER, confirmationPhrase: "delete my account" }), deps);
  assertEquals(res.status, 400);
  assertEquals((await res.json()).error, "Invalid confirmation phrase");
  assertEquals(db.calls.update.length, 0);
});

Deno.test("a misconfigured runtime (no Supabase client) is a 500 configuration error", async () => {
  const { deps, db } = build({}, null);
  const res = await handleRequest(deleteReq({ userId: USER, confirmationPhrase: PHRASE }), deps);
  assertEquals(res.status, 500);
  assertEquals((await res.json()).error, "Server configuration error");
  assertEquals(db.calls.update.length, 0);
});

Deno.test("the happy path soft-deletes: 200, success body and both database updates", async () => {
  const { deps, db } = build({ update: [{ error: null }, { error: null }] });
  const res = await handleRequest(deleteReq({ userId: USER, confirmationPhrase: PHRASE }), deps);
  assertEquals(res.status, 200);
  const payload = await res.json();
  assertEquals(payload.success, true);
  assertEquals(payload.gracePeriodEndsAt, "2026-10-10T12:00:00.000Z");
  assertEquals(payload.canRecoverUntil, "2026-10-10T12:00:00.000Z");
  assert((payload.message as string).length > 0);
  assert(typeof payload.traceId === "string");
  // The auth.users soft-delete record and the profile hide are both written.
  assertEquals(db.calls.update.length, 2);
  assertEquals(db.calls.update[0], {
    soft_deleted_at: "2026-09-26T12:00:00.000Z",
    deleted_at: "2026-10-10T12:00:00.000Z",
    email: `deleted-${USER}@deleted.local`,
  });
  assertEquals(db.calls.update[1], { hidden: true });
});

Deno.test("a database failure on the soft-delete step is a 500 and nothing succeeds", async () => {
  const { deps, db } = build({ update: [{ error: { message: "RLS violation" } }] });
  const res = await handleRequest(deleteReq({ userId: USER, confirmationPhrase: PHRASE }), deps);
  assertEquals(res.status, 500);
  const payload = await res.json();
  assertEquals(payload.success, undefined);
  assertEquals(payload.error, "Failed to delete account");
  // The profile hide must never run after a failed soft-delete.
  assertEquals(db.calls.update.length, 1);
});

Deno.test("a failure to hide the profile is NOT reported as success", async () => {
  // Previously this path only logged a warning and returned 200 even though
  // the user's posts stayed visible after the deletion request.
  const { deps, db } = build({ update: [{ error: null }, { error: { message: "profiles locked" } }] });
  const res = await handleRequest(deleteReq({ userId: USER, confirmationPhrase: PHRASE }), deps);
  assertEquals(res.status, 500);
  const payload = await res.json();
  assertEquals(payload.error, "Failed to hide profile data");
  assert(!("success" in payload));
});

Deno.test("the client's incoming trace id is echoed back on responses", async () => {
  const { deps } = build();
  const res = await handleRequest(
    jsonRequest(undefined, { method: "GET", headers: { "x-trace-id": "trace-abc" } }),
    deps,
  );
  assertEquals(res.headers.get("X-Trace-ID"), "trace-abc");
  assertEquals(res.headers.get("X-Request-ID"), "trace-abc");
});

Deno.test("an unexpected throw inside the handler is a 500, not a success", async () => {
  const throwing = {
    from: () => {
      throw new Error("connection reset");
    },
  };
  const { deps } = build({}, throwing);
  const res = await handleRequest(deleteReq({ userId: USER, confirmationPhrase: PHRASE }), deps);
  assertEquals(res.status, 500);
  assertEquals((await res.json()).error, "Internal server error");
});

// ── Authorization (issue #742) ─────────────────────────────────────────────

Deno.test("a missing Authorization header is 401 and no database write happens", async () => {
  const { deps, db } = build({ update: [{ error: null }, { error: null }] });
  const res = await handleRequest(deleteReq({ userId: USER, confirmationPhrase: PHRASE }, {}), deps);
  assertEquals(res.status, 401);
  const payload = await res.json();
  assertEquals(payload.error, "Missing or invalid Authorization header");
  assertEquals(db.calls.update.length, 0);
  assertEquals(db.calls.rpc.length, 0);
});

Deno.test("a non-Bearer Authorization header is 401", async () => {
  const { deps, db } = build();
  const res = await handleRequest(
    deleteReq({ userId: USER, confirmationPhrase: PHRASE }, { Authorization: `Basic ${TOKEN}` }),
    deps,
  );
  assertEquals(res.status, 401);
  assertEquals((await res.json()).error, "Missing or invalid Authorization header");
  assertEquals(db.calls.update.length, 0);
});

Deno.test("an empty bearer token is 401", async () => {
  const { deps, db } = build();
  const res = await handleRequest(
    deleteReq({ userId: USER, confirmationPhrase: PHRASE }, { Authorization: "Bearer " }),
    deps,
  );
  assertEquals(res.status, 401);
  assertEquals(db.calls.update.length, 0);
});

Deno.test("when getUser returns an error the request is 401 and nothing is written", async () => {
  const { deps, db } = build();
  deps.getUser = async () => ({ user: null, error: { message: "JWT expired" } });
  const res = await handleRequest(deleteReq({ userId: USER, confirmationPhrase: PHRASE }), deps);
  assertEquals(res.status, 401);
  assertEquals((await res.json()).error, "Unauthorized");
  assertEquals(db.calls.update.length, 0);
});

Deno.test("when getUser returns a different user the request is 403 with no writes", async () => {
  const { deps, db } = build({ update: [{ error: null }, { error: null }] });
  const other = "99999999-8888-7777-6666-555555555555";
  deps.getUser = async () => ({ user: { id: other } });
  const res = await handleRequest(deleteReq({ userId: USER, confirmationPhrase: PHRASE }), deps);
  assertEquals(res.status, 403);
  const payload = await res.json();
  assertEquals(payload.error, "User mismatch");
  assertEquals(db.calls.update.length, 0);
  assertEquals(db.calls.rpc.length, 0);
});

Deno.test("authorization is checked BEFORE the confirmation phrase", async () => {
  // A bad phrase with no token must answer 401, not 400.
  const { deps, db } = build();
  const res = await handleRequest(
    deleteReq({ userId: USER, confirmationPhrase: "wrong" }, {}),
    deps,
  );
  assertEquals(res.status, 401);
  assertEquals(db.calls.update.length, 0);
});

Deno.test("a valid token for the same user deletes successfully", async () => {
  const { deps, db } = build({ update: [{ error: null }, { error: null }] });
  const res = await handleRequest(deleteReq({ userId: USER, confirmationPhrase: PHRASE }), deps);
  assertEquals(res.status, 200);
  const payload = await res.json();
  assertEquals(payload.success, true);
  // Both writes happen: the auth.users soft-delete and the profile hide.
  assertEquals(db.calls.update.length, 2);
  assertEquals(db.calls.update[1], { hidden: true });
});
