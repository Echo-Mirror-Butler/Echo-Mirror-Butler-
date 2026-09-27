import {
  assertEquals,
} from "https://deno.land/std@0.192.0/testing/asserts.ts";
import { exportUserDataFunction } from "./export-user-data/index.ts";
import {
  createMockRequest,
  getResponseBody,
  createMockSupabaseClient,
} from "./_shared/testing.ts";

Deno.test("export-user-data: handles OPTIONS preflight", async () => {
  const req = createMockRequest("OPTIONS");
  const res = await exportUserDataFunction(req);
  assertEquals(res.status, 200);
});

Deno.test("export-user-data: rejects non-GET methods with 405", async () => {
  const req = createMockRequest("POST");
  const res = await exportUserDataFunction(req);
  assertEquals(res.status, 405);
});

Deno.test("export-user-data: rejects request missing Authorization header with 401", async () => {
  const req = createMockRequest("GET");
  const res = await exportUserDataFunction(req);
  assertEquals(res.status, 401);
});

Deno.test("export-user-data: rejects request with invalid token with 401", async () => {
  const mockClient = createMockSupabaseClient({
    authError: new Error("Token invalid"),
  });
  const req = createMockRequest("GET", undefined, { Authorization: "Bearer bad-token" });
  const res = await exportUserDataFunction(req, mockClient);
  assertEquals(res.status, 401);
});

Deno.test("export-user-data: returns full user data bundle for authenticated user", async () => {
  const mockClient = createMockSupabaseClient({
    user: { id: "user-123" },
    tableData: {
      profiles: [{ id: "user-123", username: "alex" }],
      log_entries: [{ id: "entry-1", user_id: "user-123", mood: 5 }],
      comments: [{ id: "c-1", user_id: "user-123" }],
      transactions: [{ id: "tx-1", user_id: "user-123", amount: 100 }],
      followers: [],
      following: [],
    },
  });
  const req = createMockRequest("GET", undefined, { Authorization: "Bearer valid-token" });
  const res = await exportUserDataFunction(req, mockClient);
  assertEquals(res.status, 200);
  const body = await getResponseBody(res);
  assertEquals(body.userId, "user-123");
  assertEquals(body.data.profiles.length, 1);
  assertEquals(body.data.logs.length, 1);
});
