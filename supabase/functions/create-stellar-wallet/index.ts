import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as StellarSdk from "https://esm.sh/stellar-sdk@11";

const HORIZON_TESTNET_URL = "https://horizon-testnet.stellar.org";
const FRIENDBOT_URL = "https://friendbot.stellar.org/?addr=";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: existingWallet } = await supabase
      .from("stellar_wallets").select("public_key").eq("user_id", user.id).single();

    if (existingWallet) {
      return new Response(JSON.stringify({ message: "Wallet already exists", publicKey: existingWallet.public_key }), {
        status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const keypair = StellarSdk.Keypair.random();
    const publicKey = keypair.publicKey();
    const secretKey = keypair.secret();

    console.log(`[create-stellar-wallet] Generated keypair for user ${user.id}`);

    const friendbotRes = await fetch(`${FRIENDBOT_URL}${publicKey}`);
    if (!friendbotRes.ok) {
      console.error(`[create-stellar-wallet] Friendbot failed: ${await friendbotRes.text()}`);
    } else {
      console.log(`[create-stellar-wallet] Friendbot funded account successfully`);
    }

    let balance = "0";
    try {
      const server = new StellarSdk.Horizon.Server(HORIZON_TESTNET_URL);
      const account = await server.loadAccount(publicKey);
      const xlmBalance = account.balances.find((b) => b.asset_type === "native");
      balance = xlmBalance?.balance ?? "0";
    } catch (e) {
      console.warn(`[create-stellar-wallet] Could not verify balance: ${e}`);
    }

    const { error: insertError } = await supabase.from("stellar_wallets").insert({
      user_id: user.id,
      public_key: publicKey,
      encrypted_secret: secretKey,
      network: "testnet",
      created_at: new Date().toISOString(),
    });

    if (insertError) {
      return new Response(JSON.stringify({ error: "Failed to save wallet", details: insertError.message }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({
      success: true, publicKey, network: "testnet",
      horizonUrl: HORIZON_TESTNET_URL, balance, funded: friendbotRes.ok,
    }), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });

  } catch (err) {
    return new Response(JSON.stringify({ error: "Internal server error", details: String(err) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
