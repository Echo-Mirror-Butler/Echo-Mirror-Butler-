import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

/**
 * Request handler for `get-crypto-price`, separated from `index.ts` so it can be
 * called without starting a server: `index.ts` only wires it to `serve()`, while
 * the tests import this module with injected dependencies and never touch
 * Supabase or CoinGecko (issue #735).
 */

export const COINGECKO_API_URL = "https://api.coingecko.com/api/v3/simple/price";
export const CACHE_TTL_MINUTES = 5;
export const STALE_THRESHOLD_MINUTES = 60;

export const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface CachedPrice {
  coin_id: string;
  usd_price: number;
  last_updated: string;
  created_at: string;
}

export interface GetCryptoPriceDeps {
  /** Anything with Supabase's `.from(table)...` chain; the tests pass a fake. */
  supabase: ReturnType<typeof createClient>;
  fetch: typeof fetch;
  now?: () => Date;
}

function respond(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

export function createSupabaseClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );
}

export async function handleRequest(
  req: Request,
  deps: GetCryptoPriceDeps,
): Promise<Response> {
  // CORS preflight and method handling: without these an OPTIONS request was
  // answered with a price, and a GET would have been accepted as a price lookup.
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return respond({ error: "Method not allowed", code: "METHOD_NOT_ALLOWED" }, 405);
  }

  const supabaseClient = deps.supabase;
  const doFetch = deps.fetch;
  const now = (deps.now ?? (() => new Date()))();

  let body: { coin?: string };
  try {
    body = await req.json();
  } catch {
    // Previously a malformed body escaped to the outer catch and came back as a
    // 500. Invalid input is a client error, so it is reported as one.
    return respond({ error: "Invalid JSON body", code: "INVALID_BODY" }, 400);
  }

  const coin = body?.coin ?? "stellar";

  try {
    const { data: cachedData, error: cacheError } = await supabaseClient
      .from("crypto_price_cache")
      .select("*")
      .eq("coin_id", coin)
      .single();

    const cached = cachedData as CachedPrice | null;

    if (cached && !cacheError) {
      const lastUpdated = new Date(cached.last_updated);
      const ageMinutes = (now.getTime() - lastUpdated.getTime()) / 1000 / 60;

      if (ageMinutes < CACHE_TTL_MINUTES) {
        return respond(
          {
            coin,
            usd_price: cached.usd_price,
            cached: true,
            age_minutes: Math.round(ageMinutes),
          },
          200,
        );
      }
    }

    try {
      const coingeckoResponse = await doFetch(
        `${COINGECKO_API_URL}?ids=${coin}&vs_currencies=usd`,
        { headers: { Accept: "application/json" } },
      );

      if (!coingeckoResponse.ok) {
        throw new Error(`CoinGecko API returned ${coingeckoResponse.status}`);
      }

      const priceData = await coingeckoResponse.json();
      const usdPrice = priceData[coin]?.usd;

      if (!usdPrice) {
        throw new Error(`Price not found for coin: ${coin}`);
      }

      const { error: upsertError } = await supabaseClient
        .from("crypto_price_cache")
        .upsert(
          {
            coin_id: coin,
            usd_price: usdPrice,
            last_updated: now.toISOString(),
            created_at: cached?.created_at || now.toISOString(),
          },
          { onConflict: "coin_id" },
        );

      if (upsertError) {
        console.error("[get-crypto-price] Failed to update cache:", upsertError);
      }

      return respond({ coin, usd_price: usdPrice, cached: false, fresh: true }, 200);
    } catch (fetchError) {
      const message = fetchError instanceof Error ? fetchError.message : String(fetchError);
      console.error("[get-crypto-price] CoinGecko fetch failed:", message);

      if (cached) {
        const lastUpdated = new Date(cached.last_updated);
        const ageMinutes = (now.getTime() - lastUpdated.getTime()) / 1000 / 60;

        if (ageMinutes < STALE_THRESHOLD_MINUTES) {
          return respond(
            {
              coin,
              usd_price: cached.usd_price,
              cached: true,
              stale: true,
              age_minutes: Math.round(ageMinutes),
              warning:
                "Price data may be outdated due to upstream service unavailability",
            },
            200,
          );
        }
      }

      return respond(
        {
          error: "Failed to fetch price data and no cached data available",
          details: message,
        },
        503,
      );
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("[get-crypto-price] Error:", message);
    return respond({ error: "Internal server error", details: message }, 500);
  }
}
