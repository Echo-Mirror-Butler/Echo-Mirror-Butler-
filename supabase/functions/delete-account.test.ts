import {
  assertEquals,
} from "https://deno.land/std@0.192.0/testing/asserts.ts";
import { deleteAccountFunction } from "./delete-account/index.ts";
import {
  createMockRequest,
  getResponseBody,
  createMockSupabaseClient,
} from "./_shared/testing.ts";

Deno.test("delete-account: handles OPTIONS preflight", async () => {
  const req = createMockRequest("OPTIONS");
  const res = await deleteAccountFunction(req);
  assertEquals(res.status, 200);
});

Deno.test("delete-account: rejects non-POST methods with 405", async () => {
  const req = createMockRequest("GET");
  const res = await deleteAccountFunction(req);
  assertEquals(res.status, 405);
});

Deno.test("delete-account: rejects unauthenticated request without session with 401 (Issue #742)", async () => {
  const req = createMockRequest("POST", {
    userId: "target-user-123",
    confirmationPhrase: "DELETE MY ACCOUNT",
  });
  const res = await deleteAccountFunction(req);
  assertEquals(res.status, 401);
  const body = await getResponseBody(res);
  assertEquals(body.error, "Unauthorized");
});

Deno.test("delete-account: rejects invalid token with 401", async () => {
  const mockClient = createMockSupabaseClient({
    authError: new Error("Token expired"),
  });
  const req = createMockRequest(
    "POST",
    { userId: "user-123", confirmationPhrase: "DELETE MY ACCOUNT" },
    { Authorization: "Bearer expired-token" }
  );
  const res = await deleteAccountFunction(req, mockClient);
  assertEquals(res.status, 401);
});

Deno.test("delete-account: rejects caller deleting another user with 403 (Issue #742)", async () => {
  const mockClient = createMockSupabaseClient({
    user: { id: "attacker-user-id" },
  });
  const req = createMockRequest(
    "POST",
    { userId: "victim-user-id", confirmationPhrase: "DELETE MY ACCOUNT" },
    { Authorization: "Bearer attacker-valid-token" }
  );
  const res = await deleteAccountFunction(req, mockClient);
  assertEquals(res.status, 403);
  const body = await getResponseBody(res);
  assertEquals(body.error, "Forbidden");
});

Deno.test("delete-account: rejects incorrect confirmation phrase with 400", async () => {
  const mockClient = createMockSupabaseClient({
    user: { id: "user-123" },
  });
  const req = createMockRequest(
    "POST",
    { userId: "user-123", confirmationPhrase: "WRONG PHRASE" },
    { Authorization: "Bearer valid-token" }
  );
  const res = await deleteAccountFunction(req, mockClient);
  assertEquals(res.status, 400);
});

Deno.test("delete-account: successfully soft-deletes user account when authenticated", async () => {
  const mockClient = createMockSupabaseClient({
    user: { id: "user-123" },
  });
  const req = createMockRequest(
    "POST",
    { userId: "user-123", confirmationPhrase: "DELETE MY ACCOUNT" },
    { Authorization: "Bearer valid-token" }
  );
  const res = await deleteAccountFunction(req, mockClient);
  assertEquals(res.status, 200);
  const body = await getResponseBody(res);
  assertEquals(body.success, true);
  assertEquals(typeof body.gracePeriodEndsAt, "string");
});
