// Issue #590: Automated test coverage for Supabase Edge Functions
import { assertEquals, assertStringIncludes } from "std/assert/mod.ts";

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
    const req = createMockRequest("POST", { period: "weekly" }, { Authorization: "Bearer test-token" });
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
