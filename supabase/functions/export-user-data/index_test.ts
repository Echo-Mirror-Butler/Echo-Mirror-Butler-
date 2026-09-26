import { assertEquals, assert } from "https://deno.land/std@0.192.0/testing/asserts.ts";
import { handleRequest, type ExportUserDataDeps } from "./handler.ts";
import { optionsRequest, readJson } from "../_shared/testing.ts";

/**
 * Offline tests for export-user-data (issue #735).
 *
 * Nothing here reaches Supabase: auth and all six table reads are scripted
 * fakes, and the clock is fixed, so every case is exact.
 */

const NOW = new Date("2026-09-26T12:00:00.000Z");
const USER_ID = "user-1";

interface DbCall {
  table: string;
  selectArgs: unknown[];
  filters: Array<[string, unknown]>;
  orFilter?: string;
}

/** A Supabase stand-in with scripted `.auth.getUser()` and per-table results. */
function fakeSupabaseWithAuth(opts: {
  auth?: { data: { user: { id: string } | null }; error: { message: string } | null };
  /** Per-table results, consumed in call order for each table. */
  results: Partial<Record<string, Array<{ data: unknown; error: { message: string } | null }>>>;
}) {
  const calls: DbCall[] = [];
  const tableIdx: Record<string, number> = {};

  const makeBuilder = (table: string) => {
    const b: Record<string, unknown> = {};
    const filters: Array<[string, unknown]> = [];
    let orFilter: string | undefined;
    let selectArgs: unknown[] = [];
    const take = () => {
      const queue = opts.results[table] ?? [{ data: null, error: null }];
      const i = tableIdx[table] ?? 0;
      tableIdx[table] = i + 1;
      return queue[Math.min(i, queue.length - 1)];
    };
    const call: DbCall = { table, selectArgs: [], filters: [], orFilter: undefined };
    b.select = (...args: unknown[]) => {
      selectArgs = args;
      call.selectArgs = args;
      calls.push(call);
      return b;
    };
    b.eq = (col: string, val: unknown) => {
      filters.push([col, val]);
      call.filters = [...filters];
      return b;
    };
    b.or = (spec: string) => {
      orFilter = spec;
      call.orFilter = spec;
      return b;
    };
    b.order = () => b;
    b.then = (
      resolve: (value: unknown) => unknown,
      reject?: (reason: unknown) => unknown,
    ) => Promise.resolve(take()).then(resolve, reject);
    return b;
  };

  return {
    calls,
    client: {
      auth: {
        getUser: async () => opts.auth ?? { data: { user: { id: USER_ID } }, error: null },
      },
      from: (table: string) => makeBuilder(table),
    },
  };
}

function makeDeps(opts: {
  auth?: { data: { user: { id: string } | null }; error: { message: string } | null };
  results?: Partial<Record<string, Array<{ data: unknown; error: { message: string } | null }>>>;
  env?: Record<string, string | undefined>;
}) {
  const db = fakeSupabaseWithAuth({
    auth: opts.auth,
    results: opts.results ?? {
      profiles: [{ data: [{ id: USER_ID, display_name: "Echo" }], error: null }],
      log_entries: [{ data: [{ id: "log-1", mood: 4 }], error: null }],
      comments: [{ data: [{ id: "c-1" }], error: null }],
      transactions: [{ data: [{ id: "t-1" }], error: null }],
      follows: [
        { data: [{ follower_id: "a" }], error: null },
        { data: [{ followee_id: "b" }], error: null },
      ],
    },
  });
  const deps: ExportUserDataDeps = {
    supabase: db.client as unknown as ExportUserDataDeps["supabase"],
    env: (name) => (opts.env?.hasOwnProperty(name) ? opts.env![name] : "https://supabase.local"),
    now: () => NOW,
  };
  return { deps, db };
}

function get() {
  return new Request("http://localhost/functions/v1/test", {
    method: "GET",
    headers: { Authorization: "Bearer test-token" },
  });
}

Deno.test("OPTIONS preflight is answered with 204 and CORS headers", async () => {
  const { deps } = makeDeps({});
  const res = await handleRequest(optionsRequest(), deps);

  assertEquals(res.status, 204);
  assertEquals(res.headers.get("Access-Control-Allow-Origin"), "*");
});

Deno.test("a non-GET method is refused with 405", async () => {
  const { deps } = makeDeps({});
  const res = await handleRequest(new Request("http://localhost/functions/v1/test", { method: "POST" }), deps);

  assertEquals(res.status, 405);
  assert(String((await readJson(res)).error).includes("Method not allowed"));
});

Deno.test("a missing Bearer token is a 401", async () => {
  const { deps } = makeDeps({});
  const res = await handleRequest(new Request("http://localhost/functions/v1/test"), deps);

  assertEquals(res.status, 401);
  assert(String((await readJson(res)).error).includes("Unauthorized"));
});

Deno.test("an invalid token is a 401 and no data is read", async () => {
  const { deps, db } = makeDeps({
    auth: { data: { user: null }, error: { message: "bad token" } },
  });
  const res = await handleRequest(get(), deps);

  assertEquals(res.status, 401);
  assertEquals(db.calls.length, 0, "no table may be read for an unauthenticated request");
});

Deno.test("missing Supabase credentials is a 500 CONFIG_ERROR, not a 400", async () => {
  const { deps } = makeDeps({ env: { SUPABASE_URL: undefined, SUPABASE_SERVICE_ROLE_KEY: undefined } });
  const res = await handleRequest(get(), deps);
  const body = await readJson(res);

  assertEquals(res.status, 500);
  assertEquals(body.code, "CONFIG_ERROR");
});

Deno.test("a successful export reads all six sources and returns the full dump", async () => {
  const { deps, db } = makeDeps({});
  const res = await handleRequest(get(), deps);
  const body = await readJson(res);

  assertEquals(res.status, 200);
  assertEquals(body.userId, USER_ID);
  assertEquals(body.exportedAt, NOW.toISOString());
  const data = body.data as Record<string, unknown>;
  assertEquals(data.profile, { id: USER_ID, display_name: "Echo" });
  assertEquals((data.moodLogs as unknown[]).length, 1);
  assertEquals((data.comments as unknown[]).length, 1);
  assertEquals((data.transactions as unknown[]).length, 1);
  assertEquals(data.social, { followers: [{ follower_id: "a" }], following: [{ followee_id: "b" }] });
  assertEquals(body.summary, {
    totalMoodLogs: 1,
    totalComments: 1,
    totalTransactions: 1,
    followers: 1,
    following: 1,
  });

  const tables = db.calls.map((c) => c.table);
  assertEquals(tables, ["profiles", "log_entries", "comments", "transactions", "follows", "follows"]);
  assertEquals(db.calls[0].filters, [["id", USER_ID]]);
  assertEquals(db.calls[1].filters, [["user_id", USER_ID]]);
  assertEquals(db.calls[3].orFilter, `sender_id.eq.${USER_ID},recipient_id.eq.${USER_ID}`);
  assertEquals(db.calls[4].filters, [["followee_id", USER_ID]]);
  assertEquals(db.calls[5].filters, [["follower_id", USER_ID]]);

  // Served as a downloadable JSON file
  assertEquals(res.headers.get("Content-Type"), "application/json");
  assert((res.headers.get("Content-Disposition") ?? "").startsWith(`attachment; filename="echo-mirror-data-export-${USER_ID}-`));
});

Deno.test("an empty database still exports an empty dump with zeroed summary", async () => {
  const { deps } = makeDeps({
    results: {
      profiles: [{ data: [], error: null }],
      log_entries: [{ data: [], error: null }],
      comments: [{ data: [], error: null }],
      transactions: [{ data: [], error: null }],
      follows: [
        { data: [], error: null },
        { data: [], error: null },
      ],
    },
  });
  const res = await handleRequest(get(), deps);
  const body = await readJson(res);

  assertEquals(res.status, 200);
  const data = body.data as Record<string, unknown>;
  assertEquals(data.profile, null);
  assertEquals(body.summary, {
    totalMoodLogs: 0,
    totalComments: 0,
    totalTransactions: 0,
    followers: 0,
    following: 0,
  });
});

Deno.test("an error on one step (follows) is a 500, never a partial success", async () => {
  const { deps } = makeDeps({
    results: {
      profiles: [{ data: [{ id: USER_ID }], error: null }],
      log_entries: [{ data: [{ id: "log-1" }], error: null }],
      comments: [{ data: [], error: null }],
      transactions: [{ data: [], error: null }],
      follows: [
        { data: [{ follower_id: "a" }], error: null },
        { data: null, error: { message: "RLS violation" } },
      ],
    },
  });
  const res = await handleRequest(get(), deps);
  const body = await readJson(res);

  assertEquals(res.status, 500);
  assert(String(body.error).includes("Failed to export data"));
  assert(!("data" in body), "no partial data may leak out on a failed export");
});

Deno.test("an error on the profiles step is a 500 too", async () => {
  const { deps } = makeDeps({
    results: {
      profiles: [{ data: null, error: { message: "permission denied" } }],
      log_entries: [{ data: [], error: null }],
      comments: [{ data: [], error: null }],
      transactions: [{ data: [], error: null }],
      follows: [
        { data: [], error: null },
        { data: [], error: null },
      ],
    },
  });
  const res = await handleRequest(get(), deps);

  assertEquals(res.status, 500);
});
