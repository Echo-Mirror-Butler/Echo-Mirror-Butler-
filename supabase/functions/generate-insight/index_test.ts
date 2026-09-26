import { assertEquals, assert } from "https://deno.land/std@0.192.0/testing/asserts.ts";
import { handleRequest, type GenerateInsightDeps } from "./handler.ts";
import { CORS_HEADERS, jsonRequest, optionsRequest, readJson } from "../_shared/testing.ts";

/**
 * Offline tests for generate-insight (issue #735).
 *
 * Nothing here reaches Supabase or Gemini: auth, database counts and the AI
 * call are all injected fakes with fixed scripts, so every case is exact.
 */

const NOW = 1_790_000_000_000; // fixed "now" in ms

interface AuthScript {
  data: { user: { id: string } | null };
  error: { message: string } | null;
}

interface DbCall {
  table: string;
  filters: Array<[string, unknown]>;
  selectArgs: unknown[];
}

/**
 * A Supabase stand-in with a scripted `.auth.getUser()` and per-table count /
 * single() results. Records every table read with its filters.
 */
function fakeSupabaseWithAuth(opts: {
  auth?: AuthScript;
  /** Results of awaited head-count selects, consumed in call order. */
  counts?: Array<number | null>;
  countError?: { message: string } | null;
  /** Result of the awaited `.single()` reads, consumed in call order. */
  singles?: Array<Record<string, unknown>>;
}) {
  const calls: DbCall[] = [];
  let countIdx = 0;
  let singleIdx = 0;

  const makeBuilder = (table: string) => {
    const b: Record<string, unknown> = {};
    const filters: Array<[string, unknown]> = [];
    const record = () => {
      calls.push({ table, filters: [...filters], selectArgs: [] });
    };
    b.select = (...args: unknown[]) => {
      record();
      return b;
    };
    b.eq = (col: string, val: unknown) => {
      filters.push([col, val]);
      return b;
    };
    b.gte = (col: string, val: unknown) => {
      filters.push([col, val]);
      return b;
    };
    b.order = () => b;
    b.limit = () => b;
    b.single = () => {
      const data = opts.singles?.[singleIdx++] ?? null;
      return Promise.resolve({ data, error: null });
    };
    b.then = (
      resolve: (value: unknown) => unknown,
      reject?: (reason: unknown) => unknown,
    ) =>
      Promise.resolve({
        count: opts.counts?.[Math.min(countIdx++, opts.counts!.length - 1)] ?? 0,
        error: opts.countError ?? null,
      }).then(resolve, reject);
    return b;
  };

  return {
    calls,
    client: {
      auth: {
        getUser: async () => opts.auth ?? { data: { user: { id: "user-1" } }, error: null },
      },
      from: (table: string) => makeBuilder(table),
    },
  };
}

function makeDeps(opts: {
  auth?: AuthScript;
  counts?: Array<number | null>;
  countError?: { message: string } | null;
  singles?: Array<Record<string, unknown>>;
  apiKey?: string | undefined;
  gemini?: (req: Request) => Response | Promise<Response>;
  net?: { fail: boolean; status?: number; body?: string };
}) {
  const db = fakeSupabaseWithAuth(opts);
  const geminiCalls: unknown[] = [];
  const doFetch = async (_url: string | URL | Request, init?: RequestInit): Promise<Response> => {
    geminiCalls.push(init?.body);
    if (opts.net?.fail) throw new Error("network down");
    if (opts.gemini) return await opts.gemini(new Request("http://gemini", { method: "POST", body: init?.body as string }));
    return new Response(
      JSON.stringify({ candidates: [{ content: { parts: [{ text: JSON.stringify({ prediction: "ok", suggestions: [], futureLetter: "x", stressLevel: 1, calmingMessage: "breathe", musicRecommendations: [], moodDrivers: [], bestTimeOfDay: "Morning", worstTimeOfDay: "Night", recommendations: [], moodScore: 4 }) }] } }] }),
      { status: opts.net?.status ?? 200, headers: { "Content-Type": "application/json" } },
    );
  };
  const deps: GenerateInsightDeps = {
    supabase: db.client as unknown as GenerateInsightDeps["supabase"],
    fetch: doFetch as unknown as typeof fetch,
    env: (name) => (name === "GEMINI_API_KEY" ? ("apiKey" in opts ? opts.apiKey : "test-key") : undefined),
    now: () => NOW,
  };
  return { deps, db, geminiCalls };
}

function authedPost(body: unknown, headers: Record<string, string> = {}) {
  return jsonRequest(body, { headers: { Authorization: "Bearer test-token", ...headers } });
}

const GEMINI_URL_FRAGMENT = "generativelanguage.googleapis.com";

Deno.test("OPTIONS preflight is answered with ok and CORS headers", async () => {
  const { deps } = makeDeps({});
  const res = await handleRequest(optionsRequest(), deps);

  assertEquals(res.status, 200);
  assertEquals(res.headers.get("Access-Control-Allow-Origin"), CORS_HEADERS["Access-Control-Allow-Origin"]);
  assertEquals(await res.text(), "ok");
});

Deno.test("a non-POST method is refused with 405", async () => {
  const { deps } = makeDeps({});
  const res = await handleRequest(new Request("http://localhost/functions/v1/test", { method: "GET" }), deps);

  assertEquals(res.status, 405);
  assertEquals((await readJson(res)).code, "METHOD_NOT_ALLOWED");
});

Deno.test("a malformed JSON body is a 400 with INVALID_BODY", async () => {
  const { deps } = makeDeps({ counts: [5, 0] });
  // malformedJsonRequest carries no auth header, so build an authed one manually.
  const res = await handleRequest(
    new Request("http://localhost/functions/v1/test", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: "Bearer test-token" },
      body: "{not json",
    }),
    deps,
  );

  assertEquals(res.status, 400);
  assertEquals((await readJson(res)).code, "INVALID_BODY");
});

Deno.test("a missing authorization header is a 401", async () => {
  const { deps } = makeDeps({});
  const res = await handleRequest(jsonRequest({ recentLogs: [] }), deps);

  assertEquals(res.status, 401);
  assertEquals((await readJson(res)).code, "UNAUTHORIZED");
});

Deno.test("an invalid token is a 401", async () => {
  const { deps } = makeDeps({
    auth: { data: { user: null }, error: { message: "bad token" } },
  });
  const res = await handleRequest(authedPost({ recentLogs: [] }), deps);

  assertEquals(res.status, 401);
  assertEquals((await readJson(res)).code, "UNAUTHORIZED");
});

Deno.test("fewer than 3 logs is a 422 and never reaches Gemini", async () => {
  const { deps, geminiCalls } = makeDeps({ counts: [2, 0] });
  const res = await handleRequest(authedPost({ recentLogs: [] }), deps);
  const body = await readJson(res);

  assertEquals(res.status, 422);
  assertEquals(body.code, "INSUFFICIENT_LOGS");
  assertEquals(geminiCalls.length, 0, "Gemini must not be called for too-few logs");
});

Deno.test("an insight in the last 24h is a 429 with Retry-After", async () => {
  const { deps } = makeDeps({
    counts: [5, 1],
    singles: [{ created_at: new Date(NOW - 60 * 60 * 1000).toISOString() }],
  });
  const res = await handleRequest(authedPost({ recentLogs: [] }), deps);
  const body = await readJson(res);

  assertEquals(res.status, 429);
  assertEquals(body.code, "RATE_LIMITED");
  assertEquals(res.headers.get("Retry-After"), String(23 * 60 * 60));
  assertEquals(body.retryAfter, 23 * 60 * 60);
});

Deno.test("a missing GEMINI_API_KEY is a 500 CONFIG_ERROR, not a 400", async () => {
  const { deps } = makeDeps({ counts: [5, 0], apiKey: undefined });
  const res = await handleRequest(authedPost({ recentLogs: [] }), deps);
  const body = await readJson(res);

  assertEquals(res.status, 500);
  assertEquals(body.code, "CONFIG_ERROR");
});

Deno.test("a successful privacy-preserving request returns the parsed AI payload", async () => {
  const insight = { prediction: "bright days ahead", moodScore: 4, suggestions: ["walk daily"] };
  const { deps, db, geminiCalls } = makeDeps({
    counts: [5, 0],
    gemini: () => new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: JSON.stringify(insight) }] } }] }), { status: 200 }),
  });

  const res = await handleRequest(
    authedPost({ privacyMode: true, sanitizedLogs: [{ mood: 4 }], moodTrend: { average: 3.5, min: 2, max: 5, direction: "up", slope: 0.1, volatility: 0.2 } }),
    deps,
  );
  const body = await readJson(res);

  assertEquals(res.status, 200);
  assertEquals(body, insight);
  assertEquals(geminiCalls.length, 1);
  assertEquals(db.calls.length, 2, "only mood_logs and ai_insights should be read");
  assertEquals(db.calls[0].table, "mood_logs");
  assertEquals(db.calls[1].table, "ai_insights");
});

Deno.test("the legacy plaintext path also works end to end", async () => {
  const insight = { prediction: "p", moodScore: 3, suggestions: [], futureLetter: "f", stressLevel: 2, calmingMessage: "c", musicRecommendations: [], moodDrivers: [], bestTimeOfDay: "Morning", worstTimeOfDay: "Night", recommendations: [] };
  const { deps, geminiCalls } = makeDeps({
    counts: [3, 0],
    gemini: () => new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: JSON.stringify(insight) }] } }] }), { status: 200 }),
  });

  const res = await handleRequest(authedPost({ recentLogs: [{ mood: 3 }] }), deps);
  const body = await readJson(res);

  assertEquals(res.status, 200);
  assertEquals(body, insight);
  assert(String(geminiCalls[0]).includes("Logs"));
});

Deno.test("a Gemini network failure is a 502, not a 400", async () => {
  const { deps } = makeDeps({ counts: [5, 0], net: { fail: true } });
  const res = await handleRequest(authedPost({ recentLogs: [{ mood: 3 }] }), deps);
  const body = await readJson(res);

  assertEquals(res.status, 502);
  assertEquals(body.code, "UPSTREAM_ERROR");
});

Deno.test("a non-2xx Gemini response is a 502, not a 400", async () => {
  const { deps } = makeDeps({ counts: [5, 0], net: { fail: false, status: 429 } });
  const res = await handleRequest(authedPost({ recentLogs: [{ mood: 3 }] }), deps);

  assertEquals(res.status, 502);
  const body = await readJson(res);
  assertEquals(body.code, "UPSTREAM_ERROR");
  assert(String(body.details).includes("Gemini API Error"));
});

Deno.test("a 200 Gemini response with an unusable body is a 502", async () => {
  const { deps } = makeDeps({
    counts: [5, 0],
    gemini: () => new Response("not json", { status: 200, headers: { "Content-Type": "application/json" } }),
  });
  const res = await handleRequest(authedPost({ recentLogs: [{ mood: 3 }] }), deps);

  assertEquals(res.status, 502);
  assertEquals((await readJson(res)).code, "UPSTREAM_ERROR");
});

Deno.test("an AI text that is not valid JSON is a 502, not a 500 or a 200", async () => {
  const { deps } = makeDeps({
    counts: [5, 0],
    gemini: () => new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: "{oops" }] } }] }), { status: 200 }),
  });
  const res = await handleRequest(authedPost({ recentLogs: [{ mood: 3 }] }), deps);

  assertEquals(res.status, 502);
  assertEquals((await readJson(res)).code, "UPSTREAM_ERROR");
});
