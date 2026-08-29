import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const COINGECKO_API_URL = "https://api.coingecko.com/api/v3/simple/price";
const CACHE_TTL_MINUTES = 5;
const STALE_THRESHOLD_MINUTES = 60;

interface CachedPrice {
  coin_id: string;
  usd_price: number;
  last_updated: string;
  created_at: string;
}

serve(async (req) => {
  try {
    const { coin = "stellar" } = await req.json();

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // Try to get cached price first
    const { data: cachedData, error: cacheError } = await supabaseClient
      .from("crypto_price_cache")
      .select("*")
      .eq("coin_id", coin)
      .single();

    const now = new Date();
    const cached = cachedData as CachedPrice | null;

    // Check if cache is fresh (within TTL)
    if (cached && !cacheError) {
      const lastUpdated = new Date(cached.last_updated);
      const ageMinutes = (now.getTime() - lastUpdated.getTime()) / 1000 / 60;

      if (ageMinutes < CACHE_TTL_MINUTES) {
        console.log(
          `[get-crypto-price] Serving cached price for ${coin} (age: ${ageMinutes.toFixed(1)}min)`,
        );
        return new Response(
          JSON.stringify({
            coin,
            usd_price: cached.usd_price,
            cached: true,
            age_minutes: Math.round(ageMinutes),
          }),
          {
            headers: { "Content-Type": "application/json" },
            status: 200,
          },
        );
      }
    }

    // Cache is stale or doesn't exist - fetch fresh price from CoinGecko
    try {
      const coingeckoResponse = await fetch(
        `${COINGECKO_API_URL}?ids=${coin}&vs_currencies=usd`,
        {
          headers: {
            Accept: "application/json",
          },
        },
      );

      if (!coingeckoResponse.ok) {
        throw new Error(`CoinGecko API returned ${coingeckoResponse.status}`);
      }

      const priceData = await coingeckoResponse.json();
      const usdPrice = priceData[coin]?.usd;

      if (!usdPrice) {
        throw new Error(`Price not found for coin: ${coin}`);
      }

      // Update cache
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
        console.error(
          "[get-crypto-price] Failed to update cache:",
          upsertError,
        );
      } else {
        console.log(
          `[get-crypto-price] Updated cache for ${coin}: $${usdPrice}`,
        );
      }

      return new Response(
        JSON.stringify({
          coin,
          usd_price: usdPrice,
          cached: false,
          fresh: true,
        }),
        {
          headers: { "Content-Type": "application/json" },
          status: 200,
        },
      );
    } catch (fetchError) {
      console.error("[get-crypto-price] CoinGecko fetch failed:", fetchError);

      // CoinGecko failed - try to serve stale cache if available
      if (cached) {
        const lastUpdated = new Date(cached.last_updated);
        const ageMinutes = (now.getTime() - lastUpdated.getTime()) / 1000 / 60;

        // Serve stale data if it's not too old
        if (ageMinutes < STALE_THRESHOLD_MINUTES) {
          console.log(
            `[get-crypto-price] Serving stale cache for ${coin} due to upstream failure (age: ${ageMinutes.toFixed(1)}min)`,
          );
          return new Response(
            JSON.stringify({
              coin,
              usd_price: cached.usd_price,
              cached: true,
              stale: true,
              age_minutes: Math.round(ageMinutes),
              warning:
                "Price data may be outdated due to upstream service unavailability",
            }),
            {
              headers: { "Content-Type": "application/json" },
              status: 200,
            },
          );
        }
      }

      // No usable cache - return error
      return new Response(
        JSON.stringify({
          error: "Failed to fetch price data and no cached data available",
          details: fetchError.message,
        }),
        {
          headers: { "Content-Type": "application/json" },
          status: 503,
        },
      );
    }
  } catch (error) {
    console.error("[get-crypto-price] Error:", error);
    return new Response(
      JSON.stringify({
        error: "Internal server error",
        details: error.message,
      }),
      {
        headers: { "Content-Type": "application/json" },
        status: 500,
      },
    );
  }
});
