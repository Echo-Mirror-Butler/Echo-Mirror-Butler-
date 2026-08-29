import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as StellarSdk from "https://esm.sh/stellar-sdk@11";

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

export function resolveStellarSettings() {
  const network = (Deno.env.get("STELLAR_NETWORK") ?? "testnet").toLowerCase();
  const isMainnet = network === "mainnet";

  return {
    horizonUrl: isMainnet ? "https://horizon.stellar.org" : "https://horizon-testnet.stellar.org",
    networkPassphrase: isMainnet
      ? StellarSdk.Networks.PUBLIC
      : StellarSdk.Networks.TESTNET,
    isTestnet: !isMainnet,
  };
}

export function getSettlementWeekStart(date = new Date()): string {
  const weekStart = new Date(date);
  const day = weekStart.getUTCDay();
  const daysSinceMonday = (day + 6) % 7;
  weekStart.setUTCDate(weekStart.getUTCDate() - daysSinceMonday);
  weekStart.setUTCHours(0, 0, 0, 0);
  return weekStart.toISOString().slice(0, 10);
}

export function getSettlementReason(rank: number, weekStart: string): string {
  return `leaderboard_bonus_rank_${rank}_week_${weekStart}`;
}

export function buildPayoutResult(
  rank: number,
  userId: string,
  amount: number,
  txHash: string,
  insertError?: string,
): {
  rank: number;
  userId: string;
  amount: number;
  txHash: string;
  success: boolean;
  error?: string;
} {
  return insertError
    ? {
      rank,
      userId,
      amount,
      txHash,
      success: false,
      error: `Payment succeeded but payout recording failed: ${insertError}`,
    }
    : { rank, userId, amount, txHash, success: true };
}

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

    const stellarSettings = resolveStellarSettings();
    const server = new StellarSdk.Horizon.Server(stellarSettings.horizonUrl);
    const issuerKeypair = StellarSdk.Keypair.fromSecret(ISSUER_SECRET_KEY);
    let issuerAccount = await server.loadAccount(issuerKeypair.publicKey());
    const weekStart = getSettlementWeekStart();

    const payoutResults = [];

    // 2. For each top-ranked user, calculate payout and send ECHO
    for (const entry of topUsers) {
      const payoutAmount = getPayoutAmount(entry.rank);
      if (!payoutAmount) continue;

      try {
        const rewardReason = getSettlementReason(entry.rank, weekStart);
        const { data: existingReward, error: rewardLookupError } = await supabase
          .from("echo_rewards")
          .select("id")
          .eq("user_id", entry.user_id)
          .eq("reason", rewardReason)
          .maybeSingle();

        if (rewardLookupError) {
          throw new Error(`Failed to check existing payout: ${rewardLookupError.message}`);
        }

        if (existingReward) {
          console.log(`[settle-leaderboard-rewards] Payout already recorded for rank ${entry.rank} user`);
          continue;
        }

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
          if (!stellarSettings.isTestnet) {
            throw new Error("Recipient account is not funded on Stellar mainnet");
          }
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
          .setNetworkPassphrase(stellarSettings.networkPassphrase)
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
            reason: rewardReason,
            amount: payoutAmount,
            stellar_tx_hash: txHash,
            created_at: new Date().toISOString(),
          });

        if (insertError) {
          console.error(`[settle-leaderboard-rewards] Failed to record payout: ${insertError.message}`);
          payoutResults.push(buildPayoutResult(
            entry.rank,
            entry.user_id,
            payoutAmount,
            txHash,
            insertError.message,
          ));
          continue;
        }

        // Refresh issuer account for next transaction
        issuerAccount = await server.loadAccount(issuerKeypair.publicKey());

        payoutResults.push(buildPayoutResult(
          entry.rank,
          entry.user_id,
          payoutAmount,
          txHash,
        ));

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
