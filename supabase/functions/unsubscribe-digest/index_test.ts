import { assertEquals, assert } from "https://deno.land/std@0.192.0/testing/asserts.ts";
import { HTML_FAILED, HTML_SUCCESS, extractHash, handleRequest, signToken, timingSafeEqual } from "./handler.ts";
import { fakeSupabase } from "../_shared/testing.ts";

const SECRET = "test-secret";
const USER = "11111111-2222-3333-4444-555555555555";

function link(userId: string | null, token: string | null) {
  const url = new URL("https://example.test/functions/v1/unsubscribe-digest");
  if (userId !== null) url.searchParams.set("user_id", userId);
  if (token !== null) url.searchParams.set("token", token);
  return new Request(url, { method: "GET" });
}

function build(script: Parameters<typeof fakeSupabase>[0] = {}, secret: string | undefined = SECRET) {
  const db = fakeSupabase(script);
  return { db, deps: { supabase: db.client as unknown as { from: (table: string) => unknown }, secret } };
}

const validToken = async (userId = USER) => `${userId}:${await signToken(userId, SECRET)}`;

Deno.test("a link without user_id or token is an invalid-link 400", async () => {
  const { deps } = build();
  const res = await handleRequest(link(null, null), deps);
  assertEquals(res.status, 400);
  assertEquals(await res.text(), HTML_FAILED);
});

Deno.test("a forged token is refused with 403 and nothing is written", async () => {
  const { deps, db } = build();
  const res = await handleRequest(link(USER, `${USER}:deadbeef`), deps);
  assertEquals(res.status, 403);
  assertEquals(db.calls.update.length, 0);
});

Deno.test("a token minted for another user is refused (the token binds the id)", async () => {
  const { deps, db } = build();
  const other = "99999999-8888-7777-6666-555555555555";
  const res = await handleRequest(link(USER, await validToken(other)), deps);
  assertEquals(res.status, 403);
  assertEquals(db.calls.update.length, 0);
});

Deno.test("a missing secret fails closed: 500, no write, and the published default is not accepted", async () => {
  // "" and not undefined: undefined would fall back to the default secret.
  const { deps, db } = build({ update: [{ error: null }] }, "");
  const forged = `${USER}:${await signToken(USER, "default-unsubscribe-secret")}`;
  const res = await handleRequest(link(USER, forged), deps);
  assertEquals(res.status, 500);
  assertEquals(db.calls.update.length, 0, "no configured secret must mean no database write");
});

Deno.test("a valid token unsubscribes: 200 and weekly_digest set to false", async () => {
  const { deps, db } = build({ update: [{ error: null }] });
  const res = await handleRequest(link(USER, await validToken()), deps);
  assertEquals(res.status, 200);
  assertEquals(await res.text(), HTML_SUCCESS);
  assertEquals(db.calls.update.length, 1);
  assertEquals(db.calls.update[0], { weekly_digest: false });
});

Deno.test("a bare hash without the user_id: prefix is still accepted", async () => {
  const { deps, db } = build({ update: [{ error: null }] });
  const res = await handleRequest(link(USER, await signToken(USER, SECRET)), deps);
  assertEquals(res.status, 200);
  assertEquals(db.calls.update.length, 1);
});

Deno.test("a database error while unsubscribing is a 500", async () => {
  const { deps } = build({ update: [{ error: { message: "permission denied" } }] });
  const res = await handleRequest(link(USER, await validToken()), deps);
  assertEquals(res.status, 500);
  assertEquals(await res.text(), HTML_FAILED);
});

Deno.test("a non-GET method is refused with 405", async () => {
  const { deps } = build();
  const res = await handleRequest(new Request("https://example.test/f/x", { method: "POST" }), deps);
  assertEquals(res.status, 405);
});

Deno.test("timingSafeEqual compares content and length", () => {
  assert(timingSafeEqual("abc123", "abc123"));
  assert(!timingSafeEqual("abc123", "abc124"));
  assert(!timingSafeEqual("abc", "abcd"));
  assert(timingSafeEqual("", ""));
});

Deno.test("extractHash keeps everything after the first colon", () => {
  assertEquals(extractHash("user:hash"), "hash");
  assertEquals(extractHash("bare-hash"), "bare-hash");
  assertEquals(extractHash("a:b:c"), "b:c");
});
