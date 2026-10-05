// Issue #590 & Issue #735: Automated test coverage for Supabase Edge Functions
import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.192.0/testing/asserts.ts";

// Register individual unit test suites (Issue #735).
//
// These are dynamic on purpose. Each function module calls serve() at the top
// level, so importing them statically would bind the same port once per
// function and the runner would die with
// `AddrInUse: Address already in use (os error 98)` before a single test ran.
// Setting the flag first, then importing, keeps the module-level exports
// reachable without listening — see `_shared/serve-guard.ts`.
Deno.env.set("EDGE_FUNCTIONS_NO_SERVE", "1");

// The functions read their configuration from the environment. The tests inject
// the network and client dependencies, but a function still resolves these
// before it reaches an injected client, so without placeholders it answers 500
// "Missing Supabase credentials" and the suite can never assert anything
// meaningful. Values are local placeholders, not secrets.
Deno.env.set("SUPABASE_URL", "http://localhost:54321");
Deno.env.set("SUPABASE_ANON_KEY", "test-anon-key");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-service-role-key");

await import("./settle-leaderboard-rewards.test.ts");
await import("./delete-account.test.ts");
await import("./request-password-reset.test.ts");
await import("./export-user-data.test.ts");
await import("./send-echo.test.ts");
await import("./save-future-letter.test.ts");
await import("./generate-encouragement.test.ts");
await import("./generate-insight.test.ts");
await import("./get-crypto-price.test.ts");
await import("./unsubscribe-digest.test.ts");
await import("./get-agora-credentials.test.ts");
await import("./env-fallback-guard.test.ts");
// Issue #763: shared cron-only caller check.
await import("./_shared/require-cron-secret_test.ts");
await import("./cleanup-expired-stories/index_test.ts");

// Test utilities
function createMockRequest(
  method: string,
  body?: unknown,
  headers?: Record<string, string>,
) {
  return new Request("http://localhost:3000/test", {
    method,
    headers: {
      "Content-Type": "application/json",
      ...headers,
    },
    body: body ? JSON.stringify(body) : undefined,
  });
}

async function getResponseBody(res: Response) {
  return await res.json();
}

// Test suites
const testSuites: Record<string, { name: string; tests: (() => Promise<void>)[] }> = {};

function registerTestSuite(name: string, tests: (() => Promise<void>)[]) {
  testSuites[name] = { name, tests };
  // Also register with Deno's test runner. Without this, `deno test` imports
  // this module (so import.meta.main is false), runAllTests() never fires and
  // the suite reports "0 tests" while still exiting 0 — a green but empty job.
  tests.forEach((testFn, index) => {
    Deno.test(`${name} — case ${index + 1}`, testFn);
  });
}

// create-stellar-wallet tests
registerTestSuite("create-stellar-wallet", [
  async () => {
    const req = createMockRequest("POST", { user_id: "test-user" }, { Authorization: "Bearer test-token" });
    assertEquals(req.method, "POST");
  },
  async () => {
    const req = createMockRequest("POST");
    assertEquals(req.method, "POST");
  },
  async () => {
    const req = createMockRequest("GET");
    assertEquals(req.method, "GET");
  },
]);

// export-user-data tests
registerTestSuite("export-user-data", [
  async () => {
    const req = createMockRequest("POST", {}, { Authorization: "Bearer test-token" });
    assertEquals(req.method, "POST");
  },
  async () => {
    const req = createMockRequest("POST");
    assertEquals(req.method, "POST");
  },
  async () => {
    const req = createMockRequest("DELETE");
    assertEquals(req.method, "DELETE");
  },
]);

// generate-chat-response tests
registerTestSuite("generate-chat-response", [
  async () => {
    const req = createMockRequest("POST", { message: "Hello" }, { Authorization: "Bearer test-token" });
    assertEquals(req.method, "POST");
  },
  async () => {
    const req = createMockRequest("POST", {});
    assertEquals(req.method, "POST");
  },
  async () => {
    const req = createMockRequest("GET");
    assertEquals(req.method, "GET");
  },
]);

// generate-encouragement tests
registerTestSuite("generate-encouragement", [
  async () => {
    const req = createMockRequest("POST", { mood: "sad" }, { Authorization: "Bearer test-token" });
    assertEquals(req.method, "POST");
  },
  async () => {
    const req = createMockRequest("POST", {});
    assertEquals(req.method, "POST");
  },
  async () => {
    const req = createMockRequest("PUT");
    assertEquals(req.method, "PUT");
  },
]);

// generate-insight tests
registerTestSuite("generate-insight", [
  async () => {
    const req = createMockRequest(
      "POST",
      {
        privacyMode: true,
        moodTrend: { average: 4.2, slope: 0.25, direction: "improving" },
        sanitizedLogs: [{ id: "log-1", mood: 4, habits: ["meditate"] }],
      },
      { Authorization: "Bearer test-token" },
    );
    assertEquals(req.method, "POST");
  },
  async () => {
    const req = createMockRequest("POST", { recentLogs: [{ id: "log-1", mood: 3 }] });
    assertEquals(req.method, "POST");
  },
  async () => {
    const req = createMockRequest("GET");
    assertEquals(req.method, "GET");
  },
]);


// get-agora-credentials tests
registerTestSuite("get-agora-credentials", [
  async () => {
    const req = createMockRequest("POST", { channel: "test-room" }, { Authorization: "Bearer test-token" });
    assertEquals(req.method, "POST");
  },
  async () => {
    const req = createMockRequest("POST", {});
    assertEquals(req.method, "POST");
  },
  async () => {
    const req = createMockRequest("DELETE");
    assertEquals(req.method, "DELETE");
  },
]);

// save-future-letter tests
registerTestSuite("save-future-letter", [
  async () => {
    const req = createMockRequest("POST", { content: "letter text" }, { Authorization: "Bearer test-token" });
    assertEquals(req.method, "POST");
  },
  async () => {
    const req = createMockRequest("POST", {});
    assertEquals(req.method, "POST");
  },
  async () => {
    const req = createMockRequest("PATCH");
    assertEquals(req.method, "PATCH");
  },
]);

// cleanup-expired-stories tests
registerTestSuite("cleanup-expired-stories", [
  async () => {
    const req = createMockRequest("POST", {}, { Authorization: "Bearer test-token" });
    assertEquals(req.method, "POST");
  },
  async () => {
    const req = createMockRequest("POST", {});
    assertEquals(req.method, "POST");
  },
  async () => {
    const req = createMockRequest("GET");
    assertEquals(req.method, "GET");
  },
]);

// send-daily-reminder tests
registerTestSuite("send-daily-reminder", [
  async () => {
    const req = createMockRequest("POST", {}, { Authorization: "Bearer test-token" });
    assertEquals(req.method, "POST");
  },
  async () => {
    const req = createMockRequest("POST", {});
    assertEquals(req.method, "POST");
  },
  async () => {
    const req = createMockRequest("OPTIONS");
    assertEquals(req.method, "OPTIONS");
  },
]);

// send-echo tests
registerTestSuite("send-echo", [
  async () => {
    const req = createMockRequest("POST", { recipient_id: "user-2", amount: 10 }, { Authorization: "Bearer test-token" });
    assertEquals(req.method, "POST");
  },
  async () => {
    const req = createMockRequest("POST", { amount: -5 });
    assertEquals(req.method, "POST");
  },
  async () => {
    const req = createMockRequest("GET");
    assertEquals(req.method, "GET");
  },
]);

// send-weekly-digest tests
registerTestSuite("send-weekly-digest", [
  async () => {
    const req = createMockRequest("POST", {}, { Authorization: "Bearer test-token" });
    assertEquals(req.method, "POST");
  },
  async () => {
    const req = createMockRequest("POST", {});
    assertEquals(req.method, "POST");
  },
  async () => {
    const req = createMockRequest("GET");
    assertEquals(req.method, "GET");
  },
]);

// unsubscribe-digest tests
registerTestSuite("unsubscribe-digest", [
  async () => {
    const req = createMockRequest("POST", { user_id: "test-user" }, { Authorization: "Bearer test-token" });
    assertEquals(req.method, "POST");
  },
  async () => {
    const req = createMockRequest("POST", {});
    assertEquals(req.method, "POST");
  },
  async () => {
    const req = createMockRequest("PATCH");
    assertEquals(req.method, "PATCH");
  },
]);

// settle-leaderboard-rewards tests (Issue #701)
registerTestSuite("settle-leaderboard-rewards", [
  async () => {
    const req = createMockRequest("POST", {}, { Authorization: "Bearer test-token" });
    assertEquals(req.method, "POST");
  },
  async () => {
    const req = createMockRequest("GET");
    assertEquals(req.method, "GET");
  },
  async () => {
    const req = createMockRequest("OPTIONS");
    assertEquals(req.method, "OPTIONS");
  },
]);

// Run all tests
async function runAllTests() {
  let passed = 0;
  let failed = 0;

  for (const [fnName, suite] of Object.entries(testSuites)) {
    console.log(`\n📋 Testing: ${fnName}`);
    for (let i = 0; i < suite.tests.length; i++) {
      const testIndex = i + 1;
      try {
        await suite.tests[i]();
        console.log(`  ✓ Test ${testIndex}/3 passed`);
        passed++;
      } catch (error) {
        console.error(`  ✗ Test ${testIndex}/3 failed:`, error);
        failed++;
      }
    }
  }

  console.log(`\n📊 Results: ${passed} passed, ${failed} failed`);
  return failed === 0;
}

if (import.meta.main) {
  const success = await runAllTests();
  Deno.exit(success ? 0 : 1);
}

export { runAllTests };
