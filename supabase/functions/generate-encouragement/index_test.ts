import { assertEquals, assert } from "https://deno.land/std@0.192.0/testing/asserts.ts";
import { FALLBACK_MESSAGE, GEMINI_MODEL, handleRequest, parsePayload } from "./handler.ts";
import { fakeFetch, jsonRequest, malformedJsonRequest, optionsRequest, readJson } from "../_shared/testing.ts";

/**
 * Offline tests for generate-encouragement (issue #735).
 *
 * The Gemini API and Deno.env are both injected, so every case below is fixed
 * and no test can reach the network whatever the environment holds.
 */

function build(
  { key = "test-key", handlers }: { key?: string; handlers?: Parameters<typeof fakeFetch>[0] } = {},
) {
  const net = fakeFetch(handlers ?? []);
  return {
    net,
    deps: { fetch: net.fn as unknown as typeof fetch, env: (name: string) => (name === "GEMINI_API_KEY" ? key : undefined) },
  };
}

const geminiOk = (text: string) =>
  () => Promise.resolve(new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text }] } }] }), { status: 200 }));

const validBody = { sentiment: "lonely", nearbyCount: 4 };

Deno.test("OPTIONS preflight answers ok with CORS headers", async () => {
  const { deps } = build();
  const res = await handleRequest(optionsRequest(), deps);

  assertEquals(res.status, 200);
  assertEquals(await res.text(), "ok");
  assertEquals(res.headers.get("Access-Control-Allow-Origin"), "*");
});

Deno.test("a non-POST method is refused with 405", async () => {
  const { deps } = build();
  const res = await handleRequest(new Request("http://localhost/f", { method: "GET" }), deps);

  assertEquals(res.status, 405);
  assertEquals((await readJson(res)).code, "METHOD_NOT_ALLOWED");
});

Deno.test("a malformed JSON body is a 400 INVALID_BODY", async () => {
  const { deps } = build();
  const res = await handleRequest(malformedJsonRequest(), deps);

  assertEquals(res.status, 400);
  assertEquals((await readJson(res)).code, "INVALID_BODY");
});

Deno.test("a missing sentiment is rejected instead of prompting from undefined", async () => {
  const { deps, net } = build({ handlers: [{ match: "generativelanguage", response: geminiOk("hi") }] });
  const res = await handleRequest(jsonRequest({ nearbyCount: 3 }), deps);
  const body = await readJson(res);

  assertEquals(res.status, 400);
  assertEquals(body.code, "INVALID_PAYLOAD");
  assert(String(body.error).includes("sentiment"));
  assertEquals(net.calls.length, 0, "an invalid payload must not reach the model");
});

Deno.test("a missing nearbyCount is rejected", async () => {
  const { deps } = build();
  const res = await handleRequest(jsonRequest({ sentiment: "lonely" }), deps);

  assertEquals(res.status, 400);
  assert(String((await readJson(res)).error).includes("nearbyCount"));
});

Deno.test("parsePayload refuses an empty sentiment and a negative count", () => {
  assert(parsePayload({ sentiment: "   ", nearbyCount: 1 }).error);
  assert(parsePayload({ sentiment: "ok", nearbyCount: -1 }).error);
  assert(parsePayload("nope").error);
  assertEquals(parsePayload({ sentiment: "ok", nearbyCount: 0 }).value, { sentiment: "ok", nearbyCount: 0 });
});

Deno.test("a missing API key is a 500 CONFIG_ERROR, not a 400", async () => {
  // "" rather than undefined: undefined would fall back to the default key.
  const { deps } = build({ key: "" });
  const res = await handleRequest(jsonRequest(validBody), deps);
  const body = await readJson(res);

  assertEquals(res.status, 500);
  assertEquals(body.code, "CONFIG_ERROR");
});

Deno.test("a Gemini error status becomes a 502 UPSTREAM_ERROR", async () => {
  const { deps } = build({
    handlers: [{ match: "generativelanguage", response: () => Promise.resolve(new Response("quota", { status: 429 })) }],
  });
  const res = await handleRequest(jsonRequest(validBody), deps);
  const body = await readJson(res);

  assertEquals(res.status, 502);
  assertEquals(body.code, "UPSTREAM_ERROR");
  assertEquals(body.status, 429);
});

Deno.test("a network failure while calling Gemini becomes a 502", async () => {
  const { deps } = build({
    handlers: [{ match: "generativelanguage", response: () => { throw new Error("dns exploded"); } }],
  });
  const res = await handleRequest(jsonRequest(validBody), deps);
  const body = await readJson(res);

  assertEquals(res.status, 502);
  assertEquals(body.code, "UPSTREAM_UNAVAILABLE");
  assert(String(body.details).includes("dns exploded"));
});

Deno.test("a successful call returns the model's message", async () => {
  const { deps, net } = build({
    handlers: [{ match: "generativelanguage", response: geminiOk("You are not alone today.") }],
  });
  const res = await handleRequest(jsonRequest(validBody), deps);
  const body = await readJson(res);

  assertEquals(res.status, 200);
  assertEquals(body.message, "You are not alone today.");
  assertEquals(net.calls.length, 1);
  assert(net.calls[0].includes(GEMINI_MODEL), "the URL should target the configured model");
});

Deno.test("a response without usable text falls back to the canned message", async () => {
  const { deps } = build({ handlers: [{ match: "generativelanguage", response: () => Promise.resolve(new Response(JSON.stringify({ candidates: [] }), { status: 200 })) }] });
  const res = await handleRequest(jsonRequest(validBody), deps);

  assertEquals(res.status, 200);
  assertEquals((await readJson(res)).message, FALLBACK_MESSAGE);
});

Deno.test("a 200 with an unparseable body is reported as an upstream problem", async () => {
  const { deps } = build({ handlers: [{ match: "generativelanguage", response: () => Promise.resolve(new Response("<html>", { status: 200 })) }] });
  const res = await handleRequest(jsonRequest(validBody), deps);
  const body = await readJson(res);

  assertEquals(res.status, 502);
  assertEquals(body.code, "UPSTREAM_BAD_BODY");
});
