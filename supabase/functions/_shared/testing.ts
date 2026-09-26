/**
 * Shared helpers for the offline Deno tests of the edge functions (issue #735).
 *
 * The rule these exist to enforce: a test must never touch Supabase, Stellar, an
 * AI provider or an email provider. Every dependency a handler needs is passed in
 * as an argument, so a test supplies a fake and the network is never reached.
 */

export const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/** Build a JSON request without repeating the boilerplate in every test. */
export function jsonRequest(
  body?: unknown,
  { method = "POST", headers = {} }: { method?: string; headers?: Record<string, string> } = {},
): Request {
  return new Request("http://localhost/functions/v1/test", {
    method,
    headers: { "Content-Type": "application/json", ...headers },
    body: body === undefined ? undefined : typeof body === "string" ? body : JSON.stringify(body),
  });
}

/** A request whose body is not valid JSON, for the INVALID_BODY path. */
export function malformedJsonRequest(method = "POST"): Request {
  return new Request("http://localhost/functions/v1/test", {
    method,
    headers: { "Content-Type": "application/json" },
    body: "{not json",
  });
}

export function optionsRequest(): Request {
  return new Request("http://localhost/functions/v1/test", { method: "OPTIONS" });
}

export async function readJson(res: Response): Promise<Record<string, unknown>> {
  return await res.json();
}

export interface FakeQueryResult {
  data?: unknown;
  error?: { message: string; code?: string } | null;
}

/**
 * A Supabase client stand-in that records calls and replays queued results.
 *
 * Usage:
 *   const db = fakeSupabase({ select: [{ data: null }], upsert: [{ error: null }] });
 *   ... await handleRequest(req, { supabase: db.client, fetch: fakeFetch });
 *   assertEquals(db.calls.select.length, 1);
 */
export function fakeSupabase(script: {
  select?: FakeQueryResult[];
  upsert?: FakeQueryResult[];
  insert?: FakeQueryResult[];
  update?: FakeQueryResult[];
  delete?: FakeQueryResult[];
  rpc?: FakeQueryResult[];
} = {}) {
  const calls: Record<string, unknown[]> = {
    select: [],
    upsert: [],
    insert: [],
    update: [],
    delete: [],
    rpc: [],
  };

  // Counts reads through a separate counter: the public methods record their own
  // payloads, so recording here too would double every call.
  const served: Record<string, number> = { select: 0, upsert: 0, insert: 0, update: 0, delete: 0, rpc: 0 };
  const take = (kind: keyof typeof calls) => {
    const queue = script[kind as keyof typeof script] ?? [{ data: null, error: null }];
    const index = served[kind]++;
    return queue[Math.min(index, queue.length - 1)] ?? { data: null, error: null };
  };

  const builder: Record<string, unknown> = {};
  const chain = () => builder;
  for (const method of ["select", "eq", "order", "limit", "maybeSingle", "single", "match", "in", "gte", "lte", "is", "not"]) {
    builder[method] = chain;
  }
  builder.upsert = (payload: unknown) => {
    calls.upsert.push(payload);
    lastResult = take("upsert");
    return Object.assign(Promise.resolve(lastResult), builder);
  };
  builder.insert = (payload: unknown) => {
    calls.insert.push(payload);
    lastResult = take("insert");
    return Object.assign(Promise.resolve(lastResult), builder);
  };
  builder.update = (payload: unknown) => {
    calls.update.push(payload);
    lastResult = take("update");
    return Object.assign(Promise.resolve(lastResult), builder);
  };
  builder.delete = () => {
    calls.delete.push({});
    lastResult = take("delete");
    return Object.assign(Promise.resolve(lastResult), builder);
  };
  builder.rpc = (name: string, args?: unknown) => {
    calls.rpc.push({ name, args });
    lastResult = take("rpc");
    return Object.assign(Promise.resolve(lastResult), builder);
  };
  // `select()` starts the chain and its result is what an `await` on the built
  // query returns, so the script entry is consumed exactly once per awaited call.
  let lastResult: FakeQueryResult = { data: null, error: null };
  builder.select = (...args: unknown[]) => {
    calls.select.push(args);
    lastResult = take("select");
    return builder;
  };
  builder.then = (resolve: (value: unknown) => unknown) =>
    Promise.resolve(lastResult).then(resolve);

  return {
    calls,
    client: { from: (_table: string) => builder },
  };
}

/** A fetch stand-in: map a URL fragment to a response, and count the calls. */
export function fakeFetch(handlers: Array<{ match: string | RegExp; response: () => Response | Promise<Response> }>) {
  const calls: string[] = [];
  const fn = async (input: RequestInfo | URL, _init?: RequestInit): Promise<Response> => {
    const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url;
    calls.push(url);
    for (const handler of handlers) {
      const hit = typeof handler.match === "string" ? url.includes(handler.match) : handler.match.test(url);
      if (hit) return await handler.response();
    }
    throw new Error(`fakeFetch: no handler for ${url}`);
  };
  return { calls, fn };
}

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
