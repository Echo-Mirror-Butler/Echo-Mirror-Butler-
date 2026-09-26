import { assertEquals, assert } from "https://deno.land/std@0.192.0/testing/asserts.ts";
import { corsHeaders, handleRequest, type SaveFutureLetterDeps } from "./handler.ts";
import {
  fakeFetch,
  jsonRequest,
  malformedJsonRequest,
  optionsRequest,
  readJson,
} from "../_shared/testing.ts";

/**
 * Offline tests for save-future-letter (issue #735).
 *
 * Supabase REST is reached only through an injected fake `fetch`: nothing here
 * touches a real network, database or the Deno clock.
 */

const USER_ID = "user-1";

const ENV: Record<string, string> = {
  SUPABASE_URL: "https://project.supabase.co/",
  SUPABASE_SERVICE_ROLE_KEY: "service-role-key",
};

/** A JWT-looking bearer token whose payload decodes to { sub: userId }. */
function bearer(userId: string): string {
  const payload = btoa(JSON.stringify({ sub: userId }))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
  return `Bearer h.${payload}.s`;
}

interface Fixture {
  deps: SaveFutureLetterDeps;
  net: ReturnType<typeof fakeFetch>;
  bodies: string[];
}

function fixture(opts: {
  env?: Record<string, string>;
  handlers?: Parameters<typeof fakeFetch>[0];
} = {}): Fixture {
  const bodies: string[] = [];
  const net = fakeFetch(
    opts.handlers ?? [
      // Default: no existing letter; insert returns one row.
      {
        match: /future_letters\?/,
        response: () => Promise.resolve(new Response("[]", { status: 200 })),
      },
      {
        match: /rest\/v1\/future_letters$/,
        response: () =>
          Promise.resolve(
            new Response(JSON.stringify([{ id: "letter-1", created_at: "2026-09-26T12:00:00.000Z" }]), { status: 201 }),
          ),
      },
    ],
  );
  const wrappedFetch: typeof fetch = ((input, init) => {
    if (init?.body) bodies.push(String(init.body));
    return net.fn(input as RequestInfo | URL, init);
  }) as typeof fetch;

  return {
    deps: {
      fetch: wrappedFetch,
      env: (name) => (opts.env ?? ENV)[name],
    },
    net,
    bodies,
  };
}

function post(body: unknown, auth = bearer(USER_ID)): Request {
  return jsonRequest(body, { headers: { Authorization: auth } });
}

const validBody = { userId: USER_ID, content: "a letter to the future", generatedAt: "2026-09-26T12:00:00.000Z" };

Deno.test("OPTIONS preflight is answered with 200 ok and CORS headers", async () => {
  const { deps } = fixture();
  const res = await handleRequest(optionsRequest(), deps);

  assertEquals(res.status, 200);
  assertEquals(await res.text(), "ok");
  assertEquals(res.headers.get("Access-Control-Allow-Origin"), corsHeaders["Access-Control-Allow-Origin"]);
});

Deno.test("a non-POST method is refused with 405", async () => {
  const { deps } = fixture();
  const res = await handleRequest(new Request("http://localhost/functions/v1/test", { method: "GET" }), deps);

  assertEquals(res.status, 405);
  assertEquals((await readJson(res)).code, "METHOD_NOT_ALLOWED");
});

Deno.test("a malformed JSON body is a 400 INVALID_BODY", async () => {
  const { deps } = fixture();
  const req = new Request("http://localhost/functions/v1/test", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: bearer(USER_ID) },
    body: "{not json",
  });
  const res = await handleRequest(req, deps);

  assertEquals(res.status, 400);
  assertEquals((await readJson(res)).code, "INVALID_BODY");
});

Deno.test("a missing userId is a 400 MISSING_FIELD", async () => {
  const { deps } = fixture();
  const res = await handleRequest(post({ content: "x" }), deps);

  assertEquals(res.status, 400);
  assertEquals((await readJson(res)).code, "MISSING_FIELD");
});

Deno.test("a missing content is a 400 MISSING_FIELD", async () => {
  const { deps } = fixture();
  const res = await handleRequest(post({ userId: USER_ID }), deps);

  assertEquals(res.status, 400);
  assertEquals((await readJson(res)).code, "MISSING_FIELD");
});

Deno.test("an invalid generatedAt is a 400 INVALID_GENERATED_AT", async () => {
  const { deps } = fixture();
  const res = await handleRequest(post({ ...validBody, generatedAt: "not-a-date" }), deps);

  assertEquals(res.status, 400);
  assertEquals((await readJson(res)).code, "INVALID_GENERATED_AT");
});

Deno.test("a missing authorization header is a 401 UNAUTHORIZED", async () => {
  const { deps } = fixture();
  const res = await handleRequest(jsonRequest(validBody), deps);

  assertEquals(res.status, 401);
  assertEquals((await readJson(res)).code, "UNAUTHORIZED");
});

Deno.test("an unparseable bearer token is a 401", async () => {
  const { deps } = fixture();
  const res = await handleRequest(post(validBody, "Bearer !!not-a-jwt!!"), deps);

  assertEquals(res.status, 401);
  assertEquals((await readJson(res)).code, "UNAUTHORIZED");
});

Deno.test("a userId that does not match the token subject is a 401 USER_MISMATCH", async () => {
  const { deps } = fixture();
  const res = await handleRequest(
    post({ ...validBody, userId: "someone-else" }, bearer(USER_ID)),
    deps,
  );

  assertEquals(res.status, 401);
  assertEquals((await readJson(res)).code, "USER_MISMATCH");
});

Deno.test("missing Supabase configuration is a 500 CONFIG_ERROR, not 400", async () => {
  const { deps } = fixture({ env: {} });
  const res = await handleRequest(post(validBody), deps);

  assertEquals(res.status, 500);
  assertEquals((await readJson(res)).code, "CONFIG_ERROR");
});

Deno.test("a failed Supabase query (network error) is a 502 UPSTREAM_ERROR", async () => {
  const { deps } = fixture({
    handlers: [{
      match: "",
      response: () => Promise.reject(new Error("connection refused")),
    }],
  });
  const res = await handleRequest(post(validBody), deps);

  assertEquals(res.status, 502);
  assertEquals((await readJson(res)).code, "UPSTREAM_ERROR");
});

Deno.test("a non-2xx Supabase query is a 502 UPSTREAM_ERROR, not 400", async () => {
  const { deps } = fixture({
    handlers: [{
      match: "future_letters",
      response: () => Promise.resolve(new Response("boom", { status: 500 })),
    }],
  });
  const res = await handleRequest(post(validBody), deps);

  assertEquals(res.status, 502);
  assertEquals((await readJson(res)).code, "UPSTREAM_ERROR");
});

Deno.test("a Supabase query returning an invalid JSON body is a 502", async () => {
  const { deps } = fixture({
    handlers: [{
      match: "future_letters?",
      response: () => Promise.resolve(new Response("<html>oops</html>", { status: 200 })),
    }],
  });
  const res = await handleRequest(post(validBody), deps);

  assertEquals(res.status, 502);
  assertEquals((await readJson(res)).code, "UPSTREAM_ERROR");
});

Deno.test("an existing letter short-circuits with 200 existing:true and no insert", async () => {
  const { deps, net, bodies } = fixture({
    handlers: [{
      match: "future_letters?",
      response: () =>
        Promise.resolve(
          new Response(JSON.stringify([{ id: "old-letter", created_at: "2026-01-01T00:00:00.000Z" }]), { status: 200 }),
        ),
    }],
  });
  const res = await handleRequest(post(validBody), deps);
  const body = await readJson(res);

  assertEquals(res.status, 200);
  assertEquals(body.existing, true);
  assertEquals(body.id, "old-letter");
  assertEquals(body.createdAt, "2026-01-01T00:00:00.000Z");
  assertEquals(bodies.length, 0, "an existing letter must not be re-inserted");
});

Deno.test("the happy path inserts the letter with unlock_at 30 days later and returns 201", async () => {
  const { deps, net, bodies } = fixture();
  const res = await handleRequest(post(validBody), deps);
  const body = await readJson(res);

  assertEquals(res.status, 201);
  assertEquals(body.id, "letter-1");
  assertEquals(body.createdAt, "2026-09-26T12:00:00.000Z");

  assertEquals(bodies.length, 1);
  const inserted = JSON.parse(bodies[0]) as Record<string, string>;
  assertEquals(inserted.user_id, USER_ID);
  assertEquals(inserted.content, "a letter to the future");
  assertEquals(inserted.created_at, "2026-09-26T12:00:00.000Z");
  assertEquals(inserted.unlock_at, "2026-10-26T12:00:00.000Z");

  // The service-role key must never leak into a URL, only into headers.
  for (const url of net.calls) {
    assert(!url.includes("service-role-key"), `key leaked into ${url}`);
  }
});

Deno.test("a missing generatedAt defaults to the injected clock", async () => {
  const { deps, bodies } = fixture();
  const fixed = new Date("2026-03-01T08:00:00.000Z");
  (deps as { now?: () => Date }).now = () => fixed;
  const res = await handleRequest(post({ userId: USER_ID, content: "x" }), deps);

  assertEquals(res.status, 201);
  const inserted = JSON.parse(bodies[0]) as Record<string, string>;
  assertEquals(inserted.created_at, fixed.toISOString());
  assertEquals(inserted.unlock_at, "2026-03-31T08:00:00.000Z");
});

Deno.test("a failed insert is a 502 UPSTREAM_ERROR, not 400", async () => {
  const { deps } = fixture({
    handlers: [
      { match: "future_letters?", response: () => Promise.resolve(new Response("[]", { status: 200 })) },
      { match: "rest/v1/future_letters$", response: () => Promise.resolve(new Response("nope", { status: 403 })) },
    ],
  });
  const res = await handleRequest(post(validBody), deps);

  assertEquals(res.status, 502);
  assertEquals((await readJson(res)).code, "UPSTREAM_ERROR");
});

Deno.test("a 2xx insert with an empty representation is a 502 UPSTREAM_ERROR", async () => {
  const { deps } = fixture({
    handlers: [
      { match: "future_letters?", response: () => Promise.resolve(new Response("[]", { status: 200 })) },
      { match: "rest/v1/future_letters$", response: () => Promise.resolve(new Response("[]", { status: 201 })) },
    ],
  });
  const res = await handleRequest(post(validBody), deps);

  assertEquals(res.status, 502);
  assertEquals((await readJson(res)).code, "UPSTREAM_ERROR");
});

Deno.test("an unexpected exception is a 500 INTERNAL_ERROR", async () => {
  const { deps } = fixture();
  // A throwing env getter escapes the targeted catches and lands in the outer one.
  (deps as { env: (n: string) => string }).env = () => {
    throw new Error("env exploded");
  };
  const res = await handleRequest(post(validBody), deps);

  assertEquals(res.status, 500);
  assertEquals((await readJson(res)).code, "INTERNAL_ERROR");
});
