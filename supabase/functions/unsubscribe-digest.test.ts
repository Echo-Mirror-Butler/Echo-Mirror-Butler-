import {
  assertEquals,
} from "https://deno.land/std@0.192.0/testing/asserts.ts";
import {
  verifyToken,
  unsubscribeDigestFunction,
} from "./unsubscribe-digest/index.ts";
import {
  createMockRequest,
  createMockSupabaseClient,
} from "./_shared/testing.ts";

async function computeToken(userId: string, secret: string): Promise<string> {
  const encoder = new TextEncoder();
  const keyData = encoder.encode(secret);
  const data = encoder.encode(userId);
  const key = await crypto.subtle.importKey(
    "raw",
    keyData,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign("HMAC", key, data);
  return Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

Deno.test("unsubscribe-digest: verifyToken returns true for valid token and false for forged token", async () => {
  const secret = "test-secret-123";
  const userId = "user-abc-123";
  const validToken = await computeToken(userId, secret);

  const isValid = await verifyToken(userId, validToken, secret);
  assertEquals(isValid, true);

  const isInvalid = await verifyToken(userId, "forged-token-hash", secret);
  assertEquals(isInvalid, false);
});

Deno.test("unsubscribe-digest: rejects missing query params with 400", async () => {
  const req = createMockRequest("GET", undefined, undefined, "http://localhost:3000/unsubscribe-digest");
  const res = await unsubscribeDigestFunction(req);
  assertEquals(res.status, 400);
});

Deno.test("unsubscribe-digest: rejects invalid token with 403", async () => {
  const req = createMockRequest(
    "GET",
    undefined,
    undefined,
    "http://localhost:3000/unsubscribe-digest?user_id=user-1&token=bad-token"
  );
  const res = await unsubscribeDigestFunction(req);
  assertEquals(res.status, 403);
});

Deno.test("unsubscribe-digest: successfully unsubscribes with valid token", async () => {
  const secret = "default-unsubscribe-secret";
  const userId = "user-1";
  const validToken = await computeToken(userId, secret);

  const mockClient = createMockSupabaseClient({
    tableData: {
      profiles: [{ id: userId, weekly_digest: true }],
    },
  });

  const req = createMockRequest(
    "GET",
    undefined,
    undefined,
    `http://localhost:3000/unsubscribe-digest?user_id=${userId}&token=${validToken}`
  );

  const res = await unsubscribeDigestFunction(req, mockClient);
  assertEquals(res.status, 200);
  const text = await res.text();
  assertEquals(text.includes("You're unsubscribed"), true);
});
