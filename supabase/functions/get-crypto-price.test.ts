import {
  assertEquals,
} from "https://deno.land/std@0.192.0/testing/asserts.ts";
import { getCryptoPriceFunction } from "./get-crypto-price/index.ts";
import {
  createMockRequest,
  getResponseBody,
  createMockSupabaseClient,
} from "./_shared/testing.ts";

Deno.test("get-crypto-price: handles OPTIONS preflight", async () => {
  const req = createMockRequest("OPTIONS");
  const res = await getCryptoPriceFunction(req);
  assertEquals(res.status, 200);
});

Deno.test("get-crypto-price: rejects non-POST methods with 405", async () => {
  const req = createMockRequest("GET");
  const res = await getCryptoPriceFunction(req);
  assertEquals(res.status, 405);
});

Deno.test("get-crypto-price: serves fresh cached price without fetching upstream", async () => {
  const mockClient = createMockSupabaseClient({
    tableData: {
      crypto_price_cache: [
        {
          coin_id: "stellar",
          usd_price: 0.125,
          last_updated: new Date().toISOString(),
          created_at: new Date().toISOString(),
        },
      ],
    },
  });

  const req = createMockRequest("POST", { coin: "stellar" });
  const res = await getCryptoPriceFunction(req, mockClient);
  assertEquals(res.status, 200);
  const body = await getResponseBody(res);
  assertEquals(body.usd_price, 0.125);
  assertEquals(body.cached, true);
});

Deno.test("get-crypto-price: fetches fresh price from CoinGecko when no cache exists", async () => {
  const mockClient = createMockSupabaseClient({
    tableData: {
      crypto_price_cache: [],
    },
  });
  // add upsert to mock builder
  const originalFrom = mockClient.from;
  mockClient.from = (table: string) => {
    const builder = originalFrom(table);
    builder.upsert = () => Promise.resolve({ error: null });
    return builder;
  };

  const mockFetch: typeof fetch = async () => {
    return new Response(JSON.stringify({ stellar: { usd: 0.13 } }), { status: 200 });
  };

  const req = createMockRequest("POST", { coin: "stellar" });
  const res = await getCryptoPriceFunction(req, mockClient, mockFetch);
  assertEquals(res.status, 200);
  const body = await getResponseBody(res);
  assertEquals(body.usd_price, 0.13);
  assertEquals(body.cached, false);
});
