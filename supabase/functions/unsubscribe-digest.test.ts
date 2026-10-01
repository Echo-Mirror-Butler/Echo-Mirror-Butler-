// deno-lint-ignore-file no-import-prefix
import {
  assertEquals,
  assertRejects,
  assertStringIncludes,
} from "https://deno.land/std@0.192.0/testing/asserts.ts";
import {
  unsubscribeDigestFunction,
  verifyToken,
} from "./unsubscribe-digest/index.ts";
import {
  KNOWN_WEAK_UNSUBSCRIBE_SECRET,
  UnsubscribeSecretMissingError,
} from "./_shared/unsubscribe-hmac.ts";
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
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, data);
  return Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/** Set UNSUBSCRIBE_SECRET for one test, restoring the previous value after. */
async function withUnsubscribeSecret<T>(
  secret: string | undefined,
  fn: () => Promise<T>,
): Promise<T> {
  const previous = Deno.env.get("UNSUBSCRIBE_SECRET");
  if (secret === undefined) Deno.env.delete("UNSUBSCRIBE_SECRET");
  else Deno.env.set("UNSUBSCRIBE_SECRET", secret);
  try {
    return await fn();
  } finally {
    if (previous === undefined) Deno.env.delete("UNSUBSCRIBE_SECRET");
    else Deno.env.set("UNSUBSCRIBE_SECRET", previous);
  }
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
  const req = createMockRequest(
    "GET",
    undefined,
    undefined,
    "http://localhost:3000/unsubscribe-digest",
  );
  const res = await unsubscribeDigestFunction(req);
  assertEquals(res.status, 400);
});

Deno.test("unsubscribe-digest: rejects invalid token with 403", async () => {
  await withUnsubscribeSecret("configured-secret-abc", async () => {
    const req = createMockRequest(
      "GET",
      undefined,
      undefined,
      "http://localhost:3000/unsubscribe-digest?user_id=user-1&token=bad-token",
    );
    const res = await unsubscribeDigestFunction(req);
    assertEquals(res.status, 403);
  });
});

Deno.test("unsubscribe-digest: successfully unsubscribes with valid token", async () => {
  const secret = "configured-secret-abc";
  const userId = "user-1";

  await withUnsubscribeSecret(secret, async () => {
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
      `http://localhost:3000/unsubscribe-digest?user_id=${userId}&token=${validToken}`,
    );

    const res = await unsubscribeDigestFunction(req, mockClient);
    assertEquals(res.status, 200);
    const text = await res.text();
    assertStringIncludes(text, "You're unsubscribed");
  });
});

// ─── Issue #762: no silent default secret ───────────────────────────────────

Deno.test("unsubscribe-digest: verifyToken refuses to run without a configured secret", async () => {
  await withUnsubscribeSecret(undefined, async () => {
    await assertRejects(
      () => verifyToken("user-1", "any-hash"),
      UnsubscribeSecretMissingError,
    );
  });
});

Deno.test("unsubscribe-digest: verifyToken refuses the historical default secret", async () => {
  await assertRejects(
    () => verifyToken("user-1", "any-hash", KNOWN_WEAK_UNSUBSCRIBE_SECRET),
    UnsubscribeSecretMissingError,
  );

  await withUnsubscribeSecret(KNOWN_WEAK_UNSUBSCRIBE_SECRET, async () => {
    await assertRejects(
      () => verifyToken("user-1", "any-hash"),
      UnsubscribeSecretMissingError,
    );
  });
});

Deno.test("unsubscribe-digest: the handler fails loudly (500) when the secret is unconfigured", async () => {
  await withUnsubscribeSecret(undefined, async () => {
    const req = createMockRequest(
      "GET",
      undefined,
      undefined,
      "http://localhost:3000/unsubscribe-digest?user_id=user-1&token=deadbeef",
    );
    const res = await unsubscribeDigestFunction(
      req,
      createMockSupabaseClient({}),
    );

    // Fail closed: never fall back to a publicly known HMAC key.
    assertEquals(res.status, 500);
    const text = await res.text();
    assertStringIncludes(text, "temporarily unavailable");
  });
});

Deno.test("unsubscribe-digest: a token forged with the old default secret is rejected", async () => {
  await withUnsubscribeSecret("real-secret-after-rotation", async () => {
    const userId = "user-1";
    // An attacker signs with the previously hardcoded default.
    const forged = await computeToken(userId, KNOWN_WEAK_UNSUBSCRIBE_SECRET);

    const req = createMockRequest(
      "GET",
      undefined,
      undefined,
      `http://localhost:3000/unsubscribe-digest?user_id=${userId}&token=${forged}`,
    );
    const res = await unsubscribeDigestFunction(
      req,
      createMockSupabaseClient({}),
    );

    assertEquals(res.status, 403);
  });
});
