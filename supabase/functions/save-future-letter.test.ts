import {
  assertEquals,
} from "https://deno.land/std@0.192.0/testing/asserts.ts";
import { saveFutureLetterFunction } from "./save-future-letter/index.ts";
import {
  createMockRequest,
  getResponseBody,
} from "./_shared/testing.ts";

function createMockJwt(userId: string) {
  const header = btoa(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const payload = btoa(JSON.stringify({ sub: userId, user_id: userId }));
  return `${header}.${payload}.signature`;
}

Deno.test("save-future-letter: handles OPTIONS preflight", async () => {
  const req = createMockRequest("OPTIONS");
  const res = await saveFutureLetterFunction(req);
  assertEquals(res.status, 200);
});

Deno.test("save-future-letter: rejects non-POST methods with 405", async () => {
  const req = createMockRequest("GET");
  const res = await saveFutureLetterFunction(req);
  assertEquals(res.status, 405);
});

Deno.test("save-future-letter: rejects missing userId or content with 400", async () => {
  const req = createMockRequest("POST", { content: "My future letter" });
  const res = await saveFutureLetterFunction(req);
  assertEquals(res.status, 400);
});

Deno.test("save-future-letter: rejects unauthenticated requests with 400", async () => {
  const req = createMockRequest("POST", {
    userId: "user-123",
    content: "My future letter",
  });
  const res = await saveFutureLetterFunction(req);
  assertEquals(res.status, 400);
  const body = await getResponseBody(res);
  assertEquals(body.error, "Missing authorization header");
});

Deno.test("save-future-letter: persists future letter on valid input", async () => {
  const userId = "user-123";
  const jwt = createMockJwt(userId);
  const req = createMockRequest(
    "POST",
    { userId, content: "Letter to future self" },
    { Authorization: `Bearer ${jwt}` }
  );

  const mockFetch: typeof fetch = async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = String(input);
    if (init?.method === "GET") {
      return new Response(JSON.stringify([]), { status: 200 });
    }
    if (init?.method === "POST") {
      return new Response(
        JSON.stringify([{ id: "letter-1", created_at: new Date().toISOString() }]),
        { status: 201 }
      );
    }
    return new Response("Not found", { status: 404 });
  };

  const res = await saveFutureLetterFunction(req, mockFetch);
  assertEquals(res.status, 201);
  const body = await getResponseBody(res);
  assertEquals(body.id, "letter-1");
});
