import { assertEquals, assert } from "https://deno.land/std@0.192.0/testing/asserts.ts";
import { handleRequest, type SendEchoDeps } from "./handler.ts";
import {
  fakeFetch,
  fakeSupabase,
  jsonRequest,
  malformedJsonRequest,
  optionsRequest,
  readJson,
} from "../_shared/testing.ts";

/**
 * Offline tests for send-echo (issue #735).
 *
 * Supabase, auth, Stellar and the secrets are all injected fakes: nothing here
 * reaches a network, a database or the Stellar horizon.
 */

const USER_ID = "11111111-1111-1111-1111-111111111111";
const RECIPIENT_ID = "22222222-2222-2222-2222-222222222222";

const ENV: Record<string, string> = {
  SUPABASE_URL: "https://project.supabase.co",
  SUPABASE_SERVICE_ROLE_KEY: "service-role-key",
  STELLAR_ISSUER_PUBLIC_KEY: "GAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
  WALLET_ENCRYPTION_KEY: "0123456789abcdef0123456789abcdef",
};

const RECIPIENT_WALLET = { public_key: "GRCPTPUBLICKEY", user_id: RECIPIENT_ID };
const SENDER_WALLET = { encrypted_secret: "encrypted-payload", public_key: "GSNDPUBLICKEY", balance: 50 };
const GIFT_ROW = { id: "gift-1", amount: 5 };

interface Fixture {
  deps: SendEchoDeps;
  db: ReturnType<typeof fakeSupabase>;
  stellar: { calls: unknown[] };
}

/**
 * Build a full fixture. The DB script queues results in the order the handler
 * awaits them: [idempotency lookup (only if a key is sent), recipient wallet,
 * sender wallet, gift row] for selects, [rate limit, transfer] for rpcs.
 */
function fixture(opts: {
  withKey?: boolean;
  env?: Record<string, string>;
  user?: { id: string } | null;
  userError?: { message: string } | null;
  selects?: unknown[];
  rpcs?: unknown[];
  stellar?: (args: unknown) => Promise<string>;
  decrypt?: (payload: string, key: string) => Promise<string>;
} = {}): Fixture {
  const recipient = { data: RECIPIENT_WALLET, error: null };
  const sender = { data: SENDER_WALLET, error: null };
  const gift = { data: GIFT_ROW, error: null };
  const selects = opts.selects ?? [
    ...(opts.withKey ? [{ data: null, error: null }] : []), // idempotency miss
    recipient,
    sender,
    gift,
  ];
  const script: Parameters<typeof fakeSupabase>[0] = { select: selects as never };
  script.rpc = [
    { data: true, error: null }, // rate limit passed
    { data: { success: true, gift_id: "gift-1" }, error: null }, // transfer
  ];
  if (opts.withKey) script.insert = [{ error: null }];
  const db = fakeSupabase(script);

  const stellar = {
    calls: [] as unknown[],
    impl: opts.stellar ?? (async () => "txhash-" + "a".repeat(60)),
  };

  const deps: SendEchoDeps = {
    env: (name) => (opts.env ?? ENV)[name],
    supabaseAdmin: admin(db),
    getUser: async () => ({ user: opts.user ?? { id: USER_ID }, error: opts.userError ?? null }),
    decryptSecret: opts.decrypt ?? (async () => "SSENDERSECRET"),
    sendStellarPayment: async (args) => {
      stellar.calls.push(args);
      return await stellar.impl(args);
    },
  };
  return { deps, db, stellar };
}

function post(body: unknown, key?: string): Request {
  const headers: Record<string, string> = { Authorization: "Bearer valid-token" };
  if (key) headers["Idempotency-Key"] = key;
  return jsonRequest(body, { headers });
}

/**
 * The shared fake exposes `.from()` but the handler also calls the admin
 * client's top-level `.rpc()`; expose both on one object.
 */
function admin(db: ReturnType<typeof fakeSupabase>) {
  const builder = (db.client as { from: (t: string) => Record<string, unknown> }).from("x");
  return {
    from: (table: string) => db.client.from(table),
    rpc: (name: string, args?: unknown) => (builder.rpc as (n: string, a?: unknown) => unknown)(name, args),
  } as unknown;
}

const validBody = { recipient_user_id: RECIPIENT_ID, amount: 5, message: "hello" };

Deno.test("OPTIONS preflight is answered with 200 ok", async () => {
  const { deps } = fixture();
  const res = await handleRequest(optionsRequest(), deps);

  assertEquals(res.status, 200);
  assertEquals((await readJson(res)).ok, true);
});

Deno.test("a non-POST method is refused with 405 METHOD_NOT_ALLOWED", async () => {
  const { deps } = fixture();
  const res = await handleRequest(new Request("http://localhost/functions/v1/test", { method: "GET" }), deps);

  assertEquals(res.status, 405);
  assertEquals((await readJson(res)).code, "METHOD_NOT_ALLOWED");
});

Deno.test("a malformed JSON body is a 400 INVALID_BODY", async () => {
  const { deps, db, stellar } = fixture();
  const req = new Request("http://localhost/functions/v1/test", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: "Bearer valid-token" },
    body: "{not json",
  });
  const res = await handleRequest(req, deps);

  assertEquals(res.status, 400);
  assertEquals((await readJson(res)).code, "INVALID_BODY");
  assertEquals(db.calls.rpc.length, 0, "nothing should run before the payload parses");
  assertEquals(stellar.calls.length, 0);
});

Deno.test("a request without a Bearer token is a 401", async () => {
  const { deps } = fixture();
  const res = await handleRequest(new Request("http://localhost/functions/v1/test", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(validBody),
  }), deps);

  assertEquals(res.status, 401);
  assertEquals((await readJson(res)).code, "UNAUTHORIZED");
});

Deno.test("an invalid token (auth.getUser error) is a 401", async () => {
  const { deps } = fixture({ userError: { message: "Invalid token" } });
  const res = await handleRequest(post(validBody), deps);

  assertEquals(res.status, 401);
  assertEquals((await readJson(res)).code, "UNAUTHORIZED");
});

Deno.test("missing Supabase configuration is a 500 SERVER_CONFIG_ERROR, not 400", async () => {
  const { deps } = fixture({ env: { SUPABASE_ANON_KEY: "anon" } });
  const res = await handleRequest(post(validBody), deps);

  assertEquals(res.status, 500);
  assertEquals((await readJson(res)).code, "SERVER_CONFIG_ERROR");
});

Deno.test("a missing recipient_id is a 400 MISSING_FIELD", async () => {
  const { deps } = fixture();
  const res = await handleRequest(post({ amount: 5 }), deps);

  assertEquals(res.status, 400);
  assertEquals((await readJson(res)).code, "MISSING_FIELD");
});

Deno.test("sending to yourself is a 400 SELF_SEND", async () => {
  const { deps } = fixture();
  const res = await handleRequest(post({ recipient_id: USER_ID, amount: 5 }), deps);

  assertEquals(res.status, 400);
  assertEquals((await readJson(res)).code, "SELF_SEND");
});

Deno.test("a zero or non-numeric amount is a 400 INVALID_AMOUNT", async () => {
  const { deps } = fixture();
  for (const amount of [0, -3, "5", NaN, null]) {
    const res = await handleRequest(post({ recipient_user_id: RECIPIENT_ID, amount }), deps);
    assertEquals(res.status, 400, `amount=${String(amount)}`);
    assertEquals((await readJson(res.clone())).code, "INVALID_AMOUNT");
  }
});

Deno.test("an amount above 100 is a 400 AMOUNT_EXCEEDS_LIMIT", async () => {
  const { deps } = fixture();
  const res = await handleRequest(post({ recipient_user_id: RECIPIENT_ID, amount: 101 }), deps);

  assertEquals(res.status, 400);
  assertEquals((await readJson(res)).code, "AMOUNT_EXCEEDS_LIMIT");
});

Deno.test("an unknown recipient is a 404 RECIPIENT_NOT_FOUND", async () => {
  const { deps } = fixture({
    selects: [
      { data: null, error: null }, // recipient wallet missing
      { data: SENDER_WALLET, error: null },
      { data: GIFT_ROW, error: null },
    ],
  });
  const res = await handleRequest(post(validBody), deps);

  assertEquals(res.status, 404);
  assertEquals((await readJson(res)).code, "RECIPIENT_NOT_FOUND");
});

Deno.test("a rate-limit rejection is a 429 RATE_LIMITED and never reaches Stellar", async () => {
  const { deps, stellar } = fixture({ rpcs: [] });
  const db = fakeSupabase({
    select: [
      { data: RECIPIENT_WALLET, error: null },
      { data: SENDER_WALLET, error: null },
      { data: GIFT_ROW, error: null },
    ],
    rpc: [{ data: false, error: null }],
  });
  (deps as { supabaseAdmin: unknown }).supabaseAdmin = admin(db);

  const res = await handleRequest(post(validBody), deps);

  assertEquals(res.status, 429);
  assertEquals((await readJson(res)).code, "RATE_LIMITED");
  assertEquals(stellar.calls.length, 0);
});

Deno.test("a sender without a wallet is a 400 SENDER_WALLET_NOT_FOUND", async () => {
  const { deps } = fixture({
    selects: [
      { data: RECIPIENT_WALLET, error: null },
      { data: null, error: null }, // sender wallet missing
      { data: GIFT_ROW, error: null },
    ],
  });
  const res = await handleRequest(post(validBody), deps);

  assertEquals(res.status, 400);
  assertEquals((await readJson(res)).code, "SENDER_WALLET_NOT_FOUND");
});

Deno.test("an insufficient sender balance is a 400 INSUFFICIENT_BALANCE", async () => {
  const { deps, stellar } = fixture({
    selects: [
      { data: RECIPIENT_WALLET, error: null },
      { data: { ...SENDER_WALLET, balance: 1 }, error: null },
      { data: GIFT_ROW, error: null },
    ],
  });
  const res = await handleRequest(post(validBody), deps);

  assertEquals(res.status, 400);
  assertEquals((await readJson(res)).code, "INSUFFICIENT_BALANCE");
  assertEquals(stellar.calls.length, 0);
});

Deno.test("a missing STELLAR_ISSUER_PUBLIC_KEY is a 500 SERVER_CONFIG_ERROR, not 400", async () => {
  const { deps } = fixture({ env: { ...ENV, STELLAR_ISSUER_PUBLIC_KEY: "" } });
  const res = await handleRequest(post(validBody), deps);

  assertEquals(res.status, 500);
  assertEquals((await readJson(res)).code, "SERVER_CONFIG_ERROR");
});

Deno.test("a missing WALLET_ENCRYPTION_KEY is a 500 SERVER_CONFIG_ERROR, not 400", async () => {
  const { deps } = fixture({ env: { ...ENV, WALLET_ENCRYPTION_KEY: "" } });
  const res = await handleRequest(post(validBody), deps);

  assertEquals(res.status, 500);
  assertEquals((await readJson(res)).code, "SERVER_CONFIG_ERROR");
});

Deno.test("a Stellar submission failure is a 502 STELLAR_ERROR, not 400 or 500", async () => {
  const { deps, db } = fixture({ stellar: async () => { throw new Error("horizon timeout"); } });
  const res = await handleRequest(post(validBody), deps);
  const body = await readJson(res);

  assertEquals(res.status, 502);
  assertEquals(body.code, "STELLAR_ERROR");
  // The transfer RPC must not run after a failed submission.
  assertEquals(db.calls.rpc.filter((r) => (r as { name: string }).name === "complete_echo_transfer").length, 0);
});

Deno.test("the happy path submits to Stellar, records the transfer and returns 201", async () => {
  const { deps, db, stellar } = fixture();
  const res = await handleRequest(post(validBody), deps);
  const body = await readJson(res);

  assertEquals(res.status, 201);
  assertEquals(body.success, true);
  assertEquals(body.stellar_tx_hash, "txhash-" + "a".repeat(60));
  assertEquals((body.transaction as { id: string }).id, "gift-1");

  const payment = stellar.calls[0] as { recipientPublicKey: string; amount: number; issuerPublicKey: string };
  assertEquals(payment.recipientPublicKey, "GRCPTPUBLICKEY");
  assertEquals(payment.amount, 5);
  assertEquals(payment.issuerPublicKey, ENV.STELLAR_ISSUER_PUBLIC_KEY);

  const transfer = db.calls.rpc.find((r) => (r as { name: string }).name === "complete_echo_transfer") as {
    args: Record<string, unknown>;
  };
  assertEquals(transfer.args.p_recipient_id, RECIPIENT_ID);
  assertEquals(transfer.args.p_amount, 5);
  assertEquals(db.calls.insert.length, 0, "no idempotency row without a key");
});

Deno.test("an idempotency cache hit replays the stored response with the replay header", async () => {
  const cached = { success: true, stellar_tx_hash: "old-hash" };
  const { deps, db, stellar } = fixture({
    withKey: true,
    selects: [
      { data: { response_status: 201, response_body: cached, expires_at: new Date(Date.now() + 3600_000).toISOString() }, error: null },
      { data: RECIPIENT_WALLET, error: null },
      { data: SENDER_WALLET, error: null },
      { data: GIFT_ROW, error: null },
    ],
  });
  const res = await handleRequest(post(validBody, "key-1"), deps);
  const body = await readJson(res);

  assertEquals(res.status, 201);
  assertEquals(res.headers.get("Idempotency-Replayed"), "true");
  assertEquals(body, cached);
  assertEquals(stellar.calls.length, 0, "a replay must not re-submit the payment");
  assertEquals(db.calls.insert.length, 0);
});

Deno.test("a successful request with a key stores the idempotency result", async () => {
  const { deps, db } = fixture({ withKey: true });
  const res = await handleRequest(post(validBody, "key-2"), deps);
  const body = await readJson(res);

  assertEquals(res.status, 201);
  assertEquals(body.idempotency_key, "key-2");
  const stored = db.calls.insert[0] as { idempotency_key: string; response_status: number; function_name: string };
  assertEquals(stored.idempotency_key, "key-2");
  assertEquals(stored.response_status, 201);
  assertEquals(stored.function_name, "send-echo");
});

Deno.test("a failed transfer RPC after a successful submission is a 500 DB_RECORDING_FAILED", async () => {
  const { deps } = fixture({
    rpcs: [],
  });
  const db = fakeSupabase({
    select: [
      { data: RECIPIENT_WALLET, error: null },
      { data: SENDER_WALLET, error: null },
      { data: GIFT_ROW, error: null },
    ],
    rpc: [
      { data: true, error: null }, // rate limit passed
      { error: { message: "deadlock detected" } },
    ],
  });
  (deps as { supabaseAdmin: unknown }).supabaseAdmin = admin(db);

  const res = await handleRequest(post(validBody), deps);
  const body = await readJson(res);

  assertEquals(res.status, 500);
  assertEquals(body.code, "DB_RECORDING_FAILED");
  assert(String(body.stellar_tx_hash).startsWith("txhash-"));
});

Deno.test("a transfer RPC that reports failure is a 500 with the RPC's own code", async () => {
  const { deps } = fixture({ rpcs: [] });
  const db = fakeSupabase({
    select: [
      { data: RECIPIENT_WALLET, error: null },
      { data: SENDER_WALLET, error: null },
      { data: GIFT_ROW, error: null },
    ],
    rpc: [
      { data: true, error: null },
      { data: { success: false, error: "balance changed", code: "BALANCE_CHANGED" } },
    ],
  });
  (deps as { supabaseAdmin: unknown }).supabaseAdmin = admin(db);

  const res = await handleRequest(post(validBody), deps);

  assertEquals(res.status, 500);
  assertEquals((await readJson(res)).code, "BALANCE_CHANGED");
});

Deno.test("an unexpected exception is a 500 INTERNAL_ERROR", async () => {
  const { deps } = fixture({ decrypt: async () => { throw new Error("bad key length"); } });
  const res = await handleRequest(post(validBody), deps);

  assertEquals(res.status, 500);
  assertEquals((await readJson(res)).code, "INTERNAL_ERROR");
});

// Silence the unused-import lint for fakeFetch: it is exercised indirectly by
// the shared helpers' API contract in the other function's tests.
void fakeFetch;
