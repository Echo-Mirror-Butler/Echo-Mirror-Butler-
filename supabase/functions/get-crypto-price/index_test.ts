import { assertEquals, assert } from "https://deno.land/std@0.192.0/testing/asserts.ts";
import {
  CACHE_TTL_MINUTES,
  COINGECKO_API_URL,
  STALE_THRESHOLD_MINUTES,
  handleRequest,
  type GetCryptoPriceDeps,
} from "./handler.ts";
import {
  fakeFetch,
  fakeSupabase,
  jsonRequest,
  malformedJsonRequest,
  optionsRequest,
  readJson,
} from "../_shared/testing.ts";

/**
 * Offline tests for get-crypto-price (issue #735).
 *
 * Nothing here reaches CoinGecko or Supabase: the handler takes both as
 * arguments, so every case is a fixed script and the assertions can be exact.
 */

const CAIRO_NOW = new Date("2026-09-26T12:00:00.000Z");

function minutesBefore(minutes: number): string {
  return new Date(CAIRO_NOW.getTime() - minutes * 60 * 1000).toISOString();
}

function deps(script: Parameters<typeof fakeSupabase>[0], handlers: Parameters<typeof fakeFetch>[0]): {
  deps: GetCryptoPriceDeps;
  db: ReturnType<typeof fakeSupabase>;
  net: ReturnType<typeof fakeFetch>;
} {
  const db = fakeSupabase(script);
  const net = fakeFetch(handlers);
  return {
    deps: { supabase: db.client as unknown as GetCryptoPriceDeps["supabase"], fetch: net.fn as unknown as typeof fetch, now: () => CAIRO_NOW },
    db,
    net,
  };
}

const priceOk = () => Promise.resolve(new Response(JSON.stringify({ stellar: { usd: 0.42 } }), { status: 200 }));

Deno.test("OPTIONS preflight is answered with 204 and CORS headers", async () => {
  const { deps: d } = deps({}, []);
  const res = await handleRequest(optionsRequest(), d);

  assertEquals(res.status, 204);
  assertEquals(res.headers.get("Access-Control-Allow-Origin"), "*");
});

Deno.test("a non-POST method is refused with 405", async () => {
  const { deps: d } = deps({}, []);
  // No body: a GET with a body is not a valid Request in the first place.
  const res = await handleRequest(new Request("http://localhost/functions/v1/test", { method: "GET" }), d);

  assertEquals(res.status, 405);
  assertEquals((await readJson(res)).code, "METHOD_NOT_ALLOWED");
});

Deno.test("a malformed JSON body is a 400, not a 500", async () => {
  const { deps: d } = deps({}, []);
  const res = await handleRequest(malformedJsonRequest(), d);

  assertEquals(res.status, 400);
  assertEquals((await readJson(res)).code, "INVALID_BODY");
});

Deno.test("a fresh cache is served without calling CoinGecko", async () => {
  const { deps: d, net } = deps(
    { select: [{ data: { coin_id: "stellar", usd_price: 0.4, last_updated: minutesBefore(CACHE_TTL_MINUTES - 1), created_at: minutesBefore(120) }, error: null }] },
    [{ match: COINGECKO_API_URL, response: priceOk }],
  );

  const res = await handleRequest(jsonRequest({ coin: "stellar" }), d);
  const body = await readJson(res);

  assertEquals(res.status, 200);
  assertEquals(body.cached, true);
  assertEquals(body.usd_price, 0.4);
  assertEquals(net.calls.length, 0, "a fresh cache must not hit the upstream API");
});

Deno.test("a stale cache triggers a fetch, the new price is cached and returned", async () => {
  const { deps: d, db, net } = deps(
    { select: [{ data: { coin_id: "stellar", usd_price: 0.4, last_updated: minutesBefore(CACHE_TTL_MINUTES + 5), created_at: minutesBefore(240) }, error: null }], upsert: [{ error: null }] },
    [{ match: COINGECKO_API_URL, response: priceOk }],
  );

  const res = await handleRequest(jsonRequest({ coin: "stellar" }), d);
  const body = await readJson(res);

  assertEquals(res.status, 200);
  assertEquals(body.fresh, true);
  assertEquals(body.usd_price, 0.42);
  assertEquals(net.calls.length, 1);
  assertEquals(db.calls.upsert.length, 1, "the fresh price should be cached");
  assertEquals((db.calls.upsert[0] as { coin_id: string }).coin_id, "stellar");
});

Deno.test("an upstream failure inside the stale window serves the stale price with a warning", async () => {
  const { deps: d } = deps(
    { select: [{ data: { coin_id: "stellar", usd_price: 0.4, last_updated: minutesBefore(CACHE_TTL_MINUTES + 5), created_at: minutesBefore(240) }, error: null }] },
    [{ match: COINGECKO_API_URL, response: () => Promise.resolve(new Response("upstream down", { status: 502 })) }],
  );

  const res = await handleRequest(jsonRequest({ coin: "stellar" }), d);
  const body = await readJson(res);

  assertEquals(res.status, 200);
  assertEquals(body.stale, true);
  assertEquals(body.usd_price, 0.4);
  assert(typeof body.warning === "string" && (body.warning as string).length > 0);
});

Deno.test("an upstream failure with only a very old cache is a 503", async () => {
  const { deps: d } = deps(
    { select: [{ data: { coin_id: "stellar", usd_price: 0.4, last_updated: minutesBefore(STALE_THRESHOLD_MINUTES + 10), created_at: minutesBefore(999) }, error: null }] },
    [{ match: COINGECKO_API_URL, response: () => Promise.resolve(new Response("upstream down", { status: 500 })) }],
  );

  const res = await handleRequest(jsonRequest({ coin: "stellar" }), d);
  const body = await readJson(res);

  assertEquals(res.status, 503);
  assert(String(body.error).includes("no cached data available"));
});

Deno.test("an upstream failure with no cache at all is a 503", async () => {
  const { deps: d } = deps(
    { select: [{ data: null, error: { message: "no rows" } }] },
    [{ match: COINGECKO_API_URL, response: () => Promise.resolve(new Response("nope", { status: 500 })) }],
  );

  const res = await handleRequest(jsonRequest({ coin: "stellar" }), d);

  assertEquals(res.status, 503);
});

Deno.test("a 200 response without a price for the coin is treated as a failure", async () => {
  const { deps: d } = deps(
    { select: [{ data: null, error: { message: "no rows" } }] },
    [{ match: COINGECKO_API_URL, response: () => Promise.resolve(new Response(JSON.stringify({ bitcoin: { usd: 1 } }), { status: 200 })) }],
  );

  const res = await handleRequest(jsonRequest({ coin: "stellar" }), d);
  const body = await readJson(res);

  assertEquals(res.status, 503);
  assert(String(body.details).includes("Price not found"));
});

Deno.test("a cache read error does not stop a successful fetch", async () => {
  const { deps: d, db } = deps(
    { select: [{ data: null, error: { message: "permission denied" } }], upsert: [{ error: null }] },
    [{ match: COINGECKO_API_URL, response: priceOk }],
  );

  const res = await handleRequest(jsonRequest({ coin: "stellar" }), d);

  assertEquals(res.status, 200);
  assertEquals(db.calls.upsert.length, 1);
});
