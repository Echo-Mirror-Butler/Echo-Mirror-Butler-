import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as StellarSdk from "https://esm.sh/stellar-sdk@11";

const HORIZON_TESTNET_URL = "https://horizon-testnet.stellar.org";
const FRIENDBOT_URL = "https://friendbot.stellar.org/?addr=";
const ISSUER_PUBLIC_KEY = Deno.env.get("STELLAR_ISSUER_PUBLIC_KEY") ?? "";
const ISSUER_SECRET_KEY = Deno.env.get("STELLAR_ISSUER_SECRET_KEY") ?? "";
const ECHO_TOKEN_CODE = "ECHO";

interface LeaderboardEntry {
  id: string;
  user_id: string;
  echo_earned_this_week: number;
  rank: number;
}

interface PayoutTier {
  minRank: number;
  maxRank: number;
  amount: number;
}

const PAYOUT_STRUCTURE: PayoutTier[] = [
  { minRank: 1, maxRank: 1, amount: 100 },
  { minRank: 2, maxRank: 2, amount: 75 },
  { minRank: 3, maxRank: 3, amount: 50 },
  { minRank: 4, maxRank: 10, amount: 25 },
];

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok");
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    console.log("[settle-leaderboard-rewards] Starting settlement");

    // 1. Fetch top-ranked users from this week's leaderboard
    const { data: topUsers, error: fetchError } = await supabase
      .from("leaderboard_entries")
      .select("id, user_id, echo_earned_this_week, rank")
      .order("rank", { ascending: true })
      .limit(10);

    if (fetchError || !topUsers) {
      return new Response(
        JSON.stringify({ error: "Failed to fetch leaderboard", details: fetchError?.message }),
        { status: 500 }
      );
    }

    if (topUsers.length === 0) {
      console.log("[settle-leaderboard-rewards] No leaderboard entries found");
      return new Response(JSON.stringify({ success: true, payouts: 0 }));
    }

    const server = new StellarSdk.Horizon.Server(HORIZON_TESTNET_URL);
    const issuerKeypair = StellarSdk.Keypair.fromSecret(ISSUER_SECRET_KEY);
    let issuerAccount = await server.loadAccount(issuerKeypair.publicKey());

    const payoutResults = [];

    // 2. For each top-ranked user, calculate payout and send ECHO
    for (const entry of topUsers) {
      const payoutAmount = getPayoutAmount(entry.rank);
      if (!payoutAmount) continue;

      try {
        // Get user's public key
        const { data: wallet } = await supabase
          .from("stellar_wallets")
          .select("public_key")
          .eq("user_id", entry.user_id)
          .single();

        if (!wallet) {
          console.warn(`[settle-leaderboard-rewards] No wallet for user ${entry.user_id}`);
          continue;
        }

        const recipientPublicKey = wallet.public_key;

        // Check if recipient account is funded, if not, fund via Friendbot
        let recipientAccount;
        try {
          recipientAccount = await server.loadAccount(recipientPublicKey);
        } catch (e) {
          console.log(`[settle-leaderboard-rewards] Recipient unfunded, attempting Friendbot...`);
          const friendbotRes = await fetch(`${FRIENDBOT_URL}${recipientPublicKey}`);
          if (!friendbotRes.ok) {
            console.error(`[settle-leaderboard-rewards] Friendbot failed for ${recipientPublicKey}`);
            continue;
          }
          recipientAccount = await server.loadAccount(recipientPublicKey);
        }

        // Build and submit ECHO payment
        const echoAsset = new StellarSdk.Asset(ECHO_TOKEN_CODE, ISSUER_PUBLIC_KEY);
        const transaction = new StellarSdk.TransactionBuilder(issuerAccount)
          .addOperation(
            StellarSdk.Operation.payment({
              destination: recipientPublicKey,
              asset: echoAsset,
              amount: payoutAmount.toString(),
            })
          )
          .setNetworkPassphrase(StellarSdk.Networks.TESTNET_NETWORK_PASSPHRASE)
          .setTimeout(30)
          .build();

        transaction.sign(issuerKeypair);
        const result = await server.submitTransaction(transaction);

        const txHash = result.hash;
        console.log(`[settle-leaderboard-rewards] Sent ${payoutAmount} ECHO to rank ${entry.rank} user, tx: ${txHash}`);

        // 3. Record payout in rewards ledger
        const { error: insertError } = await supabase
          .from("echo_rewards")
          .insert({
            user_id: entry.user_id,
            reason: `leaderboard_bonus_rank_${entry.rank}`,
            amount: payoutAmount,
            stellar_tx_hash: txHash,
            created_at: new Date().toISOString(),
          });

        if (insertError) {
          console.error(`[settle-leaderboard-rewards] Failed to record payout: ${insertError.message}`);
        }

        // Refresh issuer account for next transaction
        issuerAccount = await server.loadAccount(issuerKeypair.publicKey());

        payoutResults.push({
          rank: entry.rank,
          userId: entry.user_id,
          amount: payoutAmount,
          txHash,
          success: true,
        });

      } catch (e) {
        console.error(`[settle-leaderboard-rewards] Error processing rank ${entry.rank}: ${e}`);
        payoutResults.push({
          rank: entry.rank,
          userId: entry.user_id,
          success: false,
          error: String(e),
        });
      }
    }

    return new Response(JSON.stringify({
      success: true,
      settledAt: new Date().toISOString(),
      totalPayouts: payoutResults.filter((r) => r.success).length,
      results: payoutResults,
    }), { status: 200 });

  } catch (err) {
    console.error("[settle-leaderboard-rewards] Unhandled error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: String(err) }),
      { status: 500 }
    );
  }
});

function getPayoutAmount(rank: number): number | null {
  for (const tier of PAYOUT_STRUCTURE) {
    if (rank >= tier.minRank && rank <= tier.maxRank) {
      return tier.amount;
    }
  }
  return null;
}
