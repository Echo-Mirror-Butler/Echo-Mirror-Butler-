import {
  assertEquals,
  assertFalse,
  assertStringIncludes,
  assertThrows,
} from "https://deno.land/std@0.192.0/testing/asserts.ts";
import {
  buildPayoutResult,
  getSettlementReason,
  getSettlementWeekStart,
  resolveStellarSettings,
  StellarNetworkConfigError,
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

Deno.test("fails loudly when STELLAR_NETWORK is unset instead of defaulting to testnet", () => {
  const previousNetwork = Deno.env.get("STELLAR_NETWORK");
  Deno.env.delete("STELLAR_NETWORK");

  try {
    assertThrows(
      () => resolveStellarSettings(),
      StellarNetworkConfigError,
      "it is unset or empty",
    );
  } finally {
    if (previousNetwork === undefined) Deno.env.delete("STELLAR_NETWORK");
    else Deno.env.set("STELLAR_NETWORK", previousNetwork);
  }
});

Deno.test("rejects an unrecognised STELLAR_NETWORK value", () => {
  const previousNetwork = Deno.env.get("STELLAR_NETWORK");
  Deno.env.set("STELLAR_NETWORK", "public");

  try {
    assertThrows(
      () => resolveStellarSettings(),
      StellarNetworkConfigError,
      'it is "public"',
    );
  } finally {
    if (previousNetwork === undefined) Deno.env.delete("STELLAR_NETWORK");
    else Deno.env.set("STELLAR_NETWORK", previousNetwork);
  }
});

Deno.test("resolves testnet settings from environment", () => {
  const previousNetwork = Deno.env.get("STELLAR_NETWORK");
  Deno.env.set("STELLAR_NETWORK", "testnet");

  try {
    const settings = resolveStellarSettings();
    assertEquals(settings.horizonUrl, "https://horizon-testnet.stellar.org");
    assertEquals(settings.isTestnet, true);
  } finally {
    if (previousNetwork === undefined) Deno.env.delete("STELLAR_NETWORK");
    else Deno.env.set("STELLAR_NETWORK", previousNetwork);
  }
});