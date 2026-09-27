import {
  assertEquals,
} from "https://deno.land/std@0.192.0/testing/asserts.ts";
import { requestPasswordResetFunction } from "./request-password-reset/index.ts";
import {
  createMockRequest,
  getResponseBody,
  createMockSupabaseClient,
} from "./_shared/testing.ts";

Deno.test("request-password-reset: handles OPTIONS preflight", async () => {
  const req = createMockRequest("OPTIONS");
  const res = await requestPasswordResetFunction(req);
  assertEquals(res.status, 200);
});

Deno.test("request-password-reset: rejects non-POST methods with 405", async () => {
  const req = createMockRequest("GET");
  const res = await requestPasswordResetFunction(req);
  assertEquals(res.status, 405);
});

Deno.test("request-password-reset: rejects unauthenticated caller without session with 401 (Issue #743)", async () => {
  const req = createMockRequest("POST", { email: "victim@example.com" });
  const res = await requestPasswordResetFunction(req);
  assertEquals(res.status, 401);
  const body = await getResponseBody(res);
  assertEquals(body.error, "Unauthorized");
});

Deno.test("request-password-reset: rejects requesting reset for an email other than caller's with 403 (Issue #743)", async () => {
  const mockClient = createMockSupabaseClient({
    user: { id: "user-1", email: "legit@example.com" },
  });
  const req = createMockRequest(
    "POST",
    { email: "other-victim@example.com" },
    { Authorization: "Bearer valid-token" }
  );
  const res = await requestPasswordResetFunction(req, mockClient);
  assertEquals(res.status, 403);
  const body = await getResponseBody(res);
  assertEquals(body.error, "Forbidden");
});

Deno.test("request-password-reset: rate limiting triggers 429 when quota exceeded", async () => {
  const mockClient = createMockSupabaseClient({
    user: { id: "user-1", email: "user@example.com" },
    rpcResponses: {
      check_auth_rate_limit: { data: false, error: null },
    },
  });
  const req = createMockRequest(
    "POST",
    { email: "user@example.com" },
    { Authorization: "Bearer valid-token" }
  );
  const res = await requestPasswordResetFunction(req, mockClient);
  assertEquals(res.status, 429);
});

Deno.test("request-password-reset: successfully accepts password reset request for authenticated user", async () => {
  const mockClient = createMockSupabaseClient({
    user: { id: "user-1", email: "user@example.com" },
    rpcResponses: {
      check_auth_rate_limit: { data: true, error: null },
    },
  });
  const req = createMockRequest(
    "POST",
    { email: "user@example.com" },
    { Authorization: "Bearer valid-token" }
  );
  const res = await requestPasswordResetFunction(req, mockClient);
  assertEquals(res.status, 200);
  const body = await getResponseBody(res);
  assertEquals(body.success, true);
});
