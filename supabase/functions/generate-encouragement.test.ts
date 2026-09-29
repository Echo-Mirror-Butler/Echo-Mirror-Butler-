import {
  assertEquals,
} from "https://deno.land/std@0.192.0/testing/asserts.ts";
import { generateEncouragementFunction } from "./generate-encouragement/index.ts";
import {
  createMockRequest,
  getResponseBody,
} from "./_shared/testing.ts";

const user = { id: "user-id" };
const allowedSupabase = {
  auth: { getUser: async () => ({ data: { user }, error: null }) },
  rpc: async () => ({ data: true, error: null }),
};

Deno.test("generate-encouragement: handles OPTIONS preflight", async () => {
  const req = createMockRequest("OPTIONS");
  const res = await generateEncouragementFunction(req);
  assertEquals(res.status, 200);
});

Deno.test("generate-encouragement: rejects non-POST methods with 405", async () => {
  const req = createMockRequest("GET");
  const res = await generateEncouragementFunction(req);
  assertEquals(res.status, 405);
});

Deno.test("generate-encouragement: errors when GEMINI_API_KEY is not set", async () => {
  const prevKey = Deno.env.get("GEMINI_API_KEY");
  Deno.env.delete("GEMINI_API_KEY");

  try {
    const req = createMockRequest("POST", { sentiment: "sad", nearbyCount: 3 }, {
      Authorization: "Bearer test-token",
    });
    const res = await generateEncouragementFunction(req, undefined, allowedSupabase);
    assertEquals(res.status, 400);
    const body = await getResponseBody(res);
    assertEquals(body.error, "GEMINI_API_KEY is not set");
  } finally {
    if (prevKey) Deno.env.set("GEMINI_API_KEY", prevKey);
  }
});

Deno.test("generate-encouragement: returns generated message on AI success", async () => {
  const prevKey = Deno.env.get("GEMINI_API_KEY");
  Deno.env.set("GEMINI_API_KEY", "test-key");

  try {
    const req = createMockRequest("POST", { sentiment: "hopeful", nearbyCount: 5 }, {
      Authorization: "Bearer test-token",
    });
    const mockFetch: typeof fetch = async () => {
      return new Response(
        JSON.stringify({
          candidates: [
            {
              content: {
                parts: [{ text: "Keep shining! Others nearby are sharing your hope." }],
              },
            },
          ],
        }),
        { status: 200 }
      );
    };

    const res = await generateEncouragementFunction(req, mockFetch, allowedSupabase);
    assertEquals(res.status, 200);
    const body = await getResponseBody(res);
    assertEquals(body.message, "Keep shining! Others nearby are sharing your hope.");
  } finally {
    if (prevKey) Deno.env.set("GEMINI_API_KEY", prevKey);
    else Deno.env.delete("GEMINI_API_KEY");
  }
});

Deno.test("generate-encouragement: handles downstream AI failure with 400", async () => {
  const prevKey = Deno.env.get("GEMINI_API_KEY");
  Deno.env.set("GEMINI_API_KEY", "test-key");

  try {
    const req = createMockRequest("POST", { sentiment: "anxious", nearbyCount: 2 }, {
      Authorization: "Bearer test-token",
    });
    const mockFetch: typeof fetch = async () => {
      return new Response("Bad Request", { status: 400, statusText: "Bad Request" });
    };

    const res = await generateEncouragementFunction(req, mockFetch, allowedSupabase);
    assertEquals(res.status, 400);
  } finally {
    if (prevKey) Deno.env.set("GEMINI_API_KEY", prevKey);
    else Deno.env.delete("GEMINI_API_KEY");
  }
});

Deno.test("generate-encouragement: rejects unauthenticated requests", async () => {
  const req = createMockRequest("POST", { sentiment: "sad", nearbyCount: 1 });
  const res = await generateEncouragementFunction(req);
  assertEquals(res.status, 401);
});

Deno.test("generate-encouragement: rejects requests over the user rate limit", async () => {
  const supabase = {
    auth: { getUser: async () => ({ data: { user }, error: null }) },
    rpc: async () => ({ data: false, error: null }),
  };
  const req = createMockRequest("POST", { sentiment: "sad", nearbyCount: 1 }, {
    Authorization: "Bearer test-token",
  });
  const res = await generateEncouragementFunction(req, undefined, supabase);
  assertEquals(res.status, 429);
});
