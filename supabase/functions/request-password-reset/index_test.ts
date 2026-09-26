import { assertEquals, assert } from "https://deno.land/std@0.192.0/testing/asserts.ts";
import {
  GENERIC_SUCCESS,
  clientIp,
  handleRequest,
  sha256Hex,
  type PasswordResetSupabase,
} from "./handler.ts";
import { jsonRequest, malformedJsonRequest, optionsRequest } from "../_shared/testing.ts";

const EMAIL = "user@example.com";

/** Local fake for the admin client: the shared fakeSupabase has no `.auth`. */
function fakeAdmin(script: {
  rpcResults?: Array<{ data?: unknown; error?: { message: string } | null }>;
  resetError?: { message: string } | null;
  resetThrows?: Error;
  resetCalls?: Array<{ email: string; options?: { redirectTo?: string } }>;
} = {}) {
  const rpcCalls: Array<{ name: string; args: unknown }> = [];
  const resetCalls = script.resetCalls ?? [];
  let rpcIndex = 0;
  const client: PasswordResetSupabase = {
    rpc: async (name: string, args?: unknown) => {
      rpcCalls.push({ name, args });
      const result = script.rpcResults?.[Math.min(rpcIndex++, (script.rpcResults?.length ?? 1) - 1)];
      return { data: result?.data, error: result?.error ?? null };
    },
    auth: {
      resetPasswordForEmail: async (email, options) => {
        resetCalls.push({ email, options });
        if (script.resetThrows) throw script.resetThrows;
        return { error: script.resetError ?? null };
      },
    },
  };
  return { client, rpcCalls, resetCalls };
}

function resetReq(body: unknown, headers: Record<string, string> = {}): Request {
  return jsonRequest(body, { headers });
}

function depsFor(admin: PasswordResetSupabase | null) {
  return { supabase: admin };
}

Deno.test("OPTIONS preflight answers 200 with CORS headers", async () => {
  const admin = fakeAdmin();
  const res = await handleRequest(optionsRequest(), depsFor(admin.client));
  assertEquals(res.status, 200);
  assertEquals(res.headers.get("Access-Control-Allow-Origin"), "*");
});

Deno.test("a non-POST method is refused with 405 and no rpc is made", async () => {
  const admin = fakeAdmin();
  const res = await handleRequest(jsonRequest(undefined, { method: "GET" }), depsFor(admin.client));
  assertEquals(res.status, 405);
  assertEquals((await res.json()).error, "Method not allowed");
  assertEquals(admin.rpcCalls.length, 0);
});

Deno.test("malformed JSON is a 400, not a 500", async () => {
  const admin = fakeAdmin();
  const res = await handleRequest(malformedJsonRequest(), depsFor(admin.client));
  assertEquals(res.status, 400);
  assertEquals((await res.json()).error, "Invalid JSON body");
  assertEquals(admin.rpcCalls.length, 0);
});

Deno.test("a non-object body (null) gets the generic success, not a 500", async () => {
  const admin = fakeAdmin({ rpcResults: [{ data: true }, { data: true }] });
  const res = await handleRequest(resetReq("null"), depsFor(admin.client));
  assertEquals(res.status, 200);
  assertEquals(await res.json(), GENERIC_SUCCESS);
});

Deno.test("an invalid email is answered generically without touching the database", async () => {
  for (const bad of ["", "not-an-email", "a@b", "@x.com"]) {
    const admin = fakeAdmin();
    const res = await handleRequest(resetReq({ email: bad }), depsFor(admin.client));
    assertEquals(res.status, 200, `email=${bad}`);
    assertEquals(await res.json(), GENERIC_SUCCESS);
    assertEquals(admin.rpcCalls.length, 0, `no rate-limit rpc for email=${bad}`);
    assertEquals(admin.resetCalls.length, 0, `no reset email for email=${bad}`);
  }
});

Deno.test("a misconfigured runtime (no admin client) is a 500 misconfiguration", async () => {
  const res = await handleRequest(resetReq({ email: EMAIL }), depsFor(null));
  assertEquals(res.status, 500);
  assertEquals((await res.json()).error, "Server misconfigured");
});

Deno.test("the happy path passes both rate-limit checks and sends the reset email", async () => {
  const admin = fakeAdmin({ rpcResults: [{ data: true }, { data: true }] });
  const res = await handleRequest(
    resetReq({ email: "  USER@Example.COM  " }),
    depsFor(admin.client),
  );
  assertEquals(res.status, 200);
  assertEquals(await res.json(), GENERIC_SUCCESS);
  // The email is normalized before hashing and before sending.
  assertEquals(admin.rpcCalls.length, 2);
  assertEquals(
    admin.rpcCalls[0].args,
    { p_key: `email:${await sha256Hex(EMAIL)}`, p_action: "password_reset", p_max_count: 3, p_window_minutes: 60 },
  );
  assertEquals(admin.rpcCalls[1].args, {
    p_key: "ip:unknown",
    p_action: "password_reset",
    p_max_count: 10,
    p_window_minutes: 60,
  });
  assertEquals(admin.resetCalls, [{ email: EMAIL, options: { redirectTo: undefined } }]);
});

Deno.test("an exhausted email quota returns 429 and no reset email is sent", async () => {
  const admin = fakeAdmin({ rpcResults: [{ data: false }] });
  const res = await handleRequest(resetReq({ email: EMAIL }), depsFor(admin.client));
  assertEquals(res.status, 429);
  assertEquals((await res.json()).error, "rate_limit_exceeded");
  assertEquals(admin.resetCalls.length, 0);
});

Deno.test("an exhausted IP quota returns 429 and no reset email is sent", async () => {
  const admin = fakeAdmin({ rpcResults: [{ data: true }, { data: false }] });
  const res = await handleRequest(resetReq({ email: EMAIL }), depsFor(admin.client));
  assertEquals(res.status, 429);
  assertEquals((await res.json()).error, "rate_limit_exceeded");
  assertEquals(admin.resetCalls.length, 0);
});

Deno.test("a broken email rate limiter is a 500 server fault, not a 429", async () => {
  // Previously this surfaced as 429 rate_limit_exceeded, telling honest
  // clients to retry in an hour when the fault is on our side.
  const admin = fakeAdmin({ rpcResults: [{ error: { message: "function not found" } }] });
  const res = await handleRequest(resetReq({ email: EMAIL }), depsFor(admin.client));
  assertEquals(res.status, 500);
  const payload = await res.json();
  assert(payload.error !== "rate_limit_exceeded");
  assertEquals(admin.resetCalls.length, 0);
});

Deno.test("a broken IP rate limiter fails closed with 500 instead of silently skipping the cap", async () => {
  // Previously the error was logged and the request continued, disabling the
  // per-IP cap whenever the limiter was down.
  const admin = fakeAdmin({ rpcResults: [{ data: true }, { error: { message: "timeout" } }] });
  const res = await handleRequest(resetReq({ email: EMAIL }), depsFor(admin.client));
  assertEquals(res.status, 500);
  assertEquals((await res.json()).error, "internal_error");
  assertEquals(admin.resetCalls.length, 0);
});

Deno.test("resetPasswordForEmail throwing (service outage) is 502, never a fake success", async () => {
  const admin = fakeAdmin({
    rpcResults: [{ data: true }, { data: true }],
    resetThrows: new Error("connect ECONNREFUSED"),
  });
  const res = await handleRequest(resetReq({ email: EMAIL }), depsFor(admin.client));
  assertEquals(res.status, 502);
  assertEquals((await res.json()).error, "service_unavailable");
});

Deno.test("a 'user not found' style auth error still returns the generic success", async () => {
  const admin = fakeAdmin({ rpcResults: [{ data: true }, { data: true }], resetError: { message: "user not found" } });
  const res = await handleRequest(resetReq({ email: EMAIL }), depsFor(admin.client));
  assertEquals(res.status, 200);
  assertEquals(await res.json(), GENERIC_SUCCESS);
});

Deno.test("an https redirectTo is passed through; an http one is dropped", async () => {
  const ok = fakeAdmin({ rpcResults: [{ data: true }, { data: true }] });
  await handleRequest(
    resetReq({ email: EMAIL, redirectTo: "https://app.example.com/custom" }),
    depsFor(ok.client),
  );
  assertEquals(ok.resetCalls[0].options?.redirectTo, "https://app.example.com/custom");

  const evil = fakeAdmin({ rpcResults: [{ data: true }, { data: true }] });
  await handleRequest(
    resetReq({ email: EMAIL, redirectTo: "http://evil.example.com" }),
    depsFor(evil.client),
  );
  assertEquals(evil.resetCalls[0].options?.redirectTo, undefined);
});

Deno.test("a spoofed non-https origin does not become the redirect target", async () => {
  const admin = fakeAdmin({ rpcResults: [{ data: true }, { data: true }] });
  await handleRequest(
    resetReq({ email: EMAIL }, { "origin": "http://evil.example.com" }),
    depsFor(admin.client),
  );
  assertEquals(admin.resetCalls[0].options?.redirectTo, undefined);
});

Deno.test("clientIp prefers x-forwarded-for, then cf/x-real, else unknown", () => {
  const req = (headers: Record<string, string>) =>
    new Request("https://x.test/f", { method: "POST", headers });
  assertEquals(clientIp(req({ "x-forwarded-for": "1.2.3.4, 5.6.7.8" })), "1.2.3.4");
  assertEquals(clientIp(req({ "x-forwarded-for": "  " })), "unknown");
  assertEquals(clientIp(req({ "cf-connecting-ip": "9.9.9.9" })), "9.9.9.9");
  assertEquals(clientIp(req({ "x-real-ip": "8.8.8.8" })), "8.8.8.8");
  assertEquals(clientIp(req({})), "unknown");
});
