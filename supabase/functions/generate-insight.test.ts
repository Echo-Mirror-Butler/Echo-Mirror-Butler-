import {
  assertEquals,
} from "https://deno.land/std@0.192.0/testing/asserts.ts";
import { generateInsightFunction } from "./generate-insight/index.ts";
import {
  createMockRequest,
  getResponseBody,
  createMockSupabaseClient,
} from "./_shared/testing.ts";

Deno.test("generate-insight: handles OPTIONS preflight", async () => {
  const req = createMockRequest("OPTIONS");
  const res = await generateInsightFunction(req);
  assertEquals(res.status, 200);
});

Deno.test("generate-insight: rejects non-POST methods with 405", async () => {
  const req = createMockRequest("GET");
  const res = await generateInsightFunction(req);
  assertEquals(res.status, 405);
});

Deno.test("generate-insight: rejects request missing Authorization header with 401", async () => {
  const req = createMockRequest("POST", {});
  const res = await generateInsightFunction(req);
  assertEquals(res.status, 401);
});

Deno.test("generate-insight: rejects when fewer than 3 logs exist with 422", async () => {
  const mockClient = createMockSupabaseClient({
    user: { id: "user-1" },
    tableData: {
      mood_logs: [{ id: "log-1", mood: 3 }],
    },
  });
  // Override select with count
  mockClient.from = () => ({
    select: () => ({
      eq: () => Promise.resolve({ count: 1, data: [{ id: "log-1" }], error: null }),
    }),
  } as any);

  const req = createMockRequest(
    "POST",
    {},
    { Authorization: "Bearer valid-token" }
  );
  const res = await generateInsightFunction(req, mockClient);
  assertEquals(res.status, 422);
  const body = await getResponseBody(res);
  assertEquals(body.error, "Need at least 3 logs to generate insight");
});
