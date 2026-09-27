import {
  assertEquals,
} from "https://deno.land/std@0.192.0/testing/asserts.ts";
import { sendEchoFunction } from "./send-echo/index.ts";
import {
  createMockRequest,
  getResponseBody,
  createMockSupabaseClient,
} from "./_shared/testing.ts";

Deno.test("send-echo: handles OPTIONS preflight", async () => {
  const req = createMockRequest("OPTIONS");
  const res = await sendEchoFunction(req);
  assertEquals(res.status, 200);
});

Deno.test("send-echo: rejects non-POST methods with 405", async () => {
  const req = createMockRequest("GET");
  const res = await sendEchoFunction(req);
  assertEquals(res.status, 405);
});

Deno.test("send-echo: rejects request missing Authorization header with 401", async () => {
  const req = createMockRequest("POST", { amount: 10 });
  const res = await sendEchoFunction(req);
  assertEquals(res.status, 401);
});

Deno.test("send-echo: rejects request with invalid authorization token with 401", async () => {
  const mockClient = createMockSupabaseClient({
    authError: new Error("Unauthorized"),
  });
  const req = createMockRequest(
    "POST",
    { amount: 10 },
    { Authorization: "Bearer bad-token" }
  );
  const res = await sendEchoFunction(req, {
    supabaseClient: mockClient,
    supabaseAdmin: mockClient,
  });
  assertEquals(res.status, 401);
});

Deno.test("send-echo: rejects request with missing recipient with 400", async () => {
  const mockClient = createMockSupabaseClient({
    user: { id: "sender-1" },
  });
  const req = createMockRequest(
    "POST",
    { amount: 10 }, // missing recipient_id
    { Authorization: "Bearer valid-token" }
  );
  const res = await sendEchoFunction(req, {
    supabaseClient: mockClient,
    supabaseAdmin: mockClient,
  });
  assertEquals(res.status, 400);
  const body = await getResponseBody(res);
  assertEquals(body.code, "INVALID_PAYLOAD");
});
