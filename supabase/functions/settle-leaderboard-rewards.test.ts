import {
  assertEquals,
  assertFalse,
  assertStringIncludes,
} from "https://deno.land/std@0.192.0/testing/asserts.ts";
import {
  buildPayoutResult,
  getSettlementReason,
  getSettlementWeekStart,
  resolveStellarSettings,
} from "./settle-leaderboard-rewards/index.ts";

Deno.test("uses one reward reason for a user's weekly settlement", () => {
  const weekStart = getSettlementWeekStart(new Date("2026-08-26T12:00:00.000Z"));
  assertEquals(weekStart, "2026-08-24");
  assertEquals(getSettlementReason(1, weekStart), "leaderboard_bonus_rank_1_week_2026-08-24");
});

Deno.test("reports a failed ledger insert after a successful payment", () => {
  const result = buildPayoutResult(1, "user-1", 100, "stellar-hash", "database unavailable");

  assertFalse(result.success);
  assertStringIncludes(result.error, "Payment succeeded but payout recording failed");
});

Deno.test("resolves Stellar mainnet settings from environment", () => {
  const previousNetwork = Deno.env.get("STELLAR_NETWORK");
  Deno.env.set("STELLAR_NETWORK", "mainnet");

  try {
    const settings = resolveStellarSettings();
    assertEquals(settings.horizonUrl, "https://horizon.stellar.org");
    assertEquals(settings.isTestnet, false);
  } finally {
    if (previousNetwork === undefined) Deno.env.delete("STELLAR_NETWORK");
    else Deno.env.set("STELLAR_NETWORK", previousNetwork);
  }
});