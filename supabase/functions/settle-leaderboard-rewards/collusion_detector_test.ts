// Issue #701: Tests for Anti-Collusion and Leaderboard Anomaly Detection
import {
  assertEquals,
  assert,
} from "https://deno.land/std@0.192.0/testing/asserts.ts";
import {
  evaluateUserCollusion,
  LeaderboardCandidate,
  GiftTransactionRecord,
  UserProfileRecord,
} from "../_shared/collusion-detector.ts";

Deno.test("CollusionDetector — Flags synthetic 2-party gift-cycling loop", () => {
  const candidate: LeaderboardCandidate = {
    user_id: "user-sybil-a",
    echo_earned_this_week: 100,
    rank: 1,
  };

  const gifts: GiftTransactionRecord[] = [
    { id: "g1", sender_id: "user-sybil-a", recipient_id: "user-sybil-b", amount: 25, created_at: "2026-08-01T10:00:00Z" },
    { id: "g2", sender_id: "user-sybil-b", recipient_id: "user-sybil-a", amount: 25, created_at: "2026-08-01T10:05:00Z" },
    { id: "g3", sender_id: "user-sybil-a", recipient_id: "user-sybil-b", amount: 25, created_at: "2026-08-01T10:10:00Z" },
    { id: "g4", sender_id: "user-sybil-b", recipient_id: "user-sybil-a", amount: 25, created_at: "2026-08-01T10:15:00Z" },
  ];

  const profiles: UserProfileRecord[] = [
    { id: "user-sybil-a", created_at: "2026-07-01T00:00:00Z" },
    { id: "user-sybil-b", created_at: "2026-07-01T00:00:00Z" },
  ];

  const result = evaluateUserCollusion(candidate, gifts, profiles, 0);

  assertEquals(result.flagged, true);
  assertEquals(result.action, "WITHHOLD_FOR_REVIEW");
  assert(result.riskScore >= 50);
  assert(result.reasons.some((r) => r.includes("High gift-loop reciprocity")));
  assertEquals(result.evidence.closedLoopPartners, ["user-sybil-b"]);
});

Deno.test("CollusionDetector — Flags account creation cluster coupled with gifting", () => {
  const candidate: LeaderboardCandidate = {
    user_id: "user-cluster-1",
    echo_earned_this_week: 60,
    rank: 2,
  };

  const gifts: GiftTransactionRecord[] = [
    { id: "g10", sender_id: "user-cluster-1", recipient_id: "user-cluster-2", amount: 30, created_at: "2026-08-01T12:00:00Z" },
    { id: "g11", sender_id: "user-cluster-2", recipient_id: "user-cluster-1", amount: 30, created_at: "2026-08-01T12:10:00Z" },
    { id: "g12", sender_id: "user-cluster-1", recipient_id: "user-cluster-2", amount: 30, created_at: "2026-08-01T12:20:00Z" },
  ];

  // Created 10 minutes apart
  const profiles: UserProfileRecord[] = [
    { id: "user-cluster-1", created_at: "2026-08-01T11:00:00Z" },
    { id: "user-cluster-2", created_at: "2026-08-01T11:10:00Z" },
  ];

  const result = evaluateUserCollusion(candidate, gifts, profiles, 0);

  assertEquals(result.flagged, true);
  assertEquals(result.action, "WITHHOLD_FOR_REVIEW");
  assert(result.reasons.some((r) => r.includes("Account creation clustering")));
});

Deno.test("CollusionDetector — Flags velocity anomaly (high reward earnings with 0 mood logs)", () => {
  const candidate: LeaderboardCandidate = {
    user_id: "user-fast-earner",
    echo_earned_this_week: 90,
    rank: 3,
  };

  const gifts: GiftTransactionRecord[] = [
    { id: "g20", sender_id: "friend-1", recipient_id: "user-fast-earner", amount: 45, created_at: "2026-08-01T12:00:00Z" },
    { id: "g21", sender_id: "friend-2", recipient_id: "user-fast-earner", amount: 45, created_at: "2026-08-01T12:05:00Z" },
  ];

  const profiles: UserProfileRecord[] = [
    { id: "user-fast-earner", created_at: "2026-05-01T00:00:00Z" },
  ];

  // 0 mood logs
  const result = evaluateUserCollusion(candidate, gifts, profiles, 0);

  assert(result.reasons.some((r) => r.includes("Velocity anomaly")));
});

Deno.test("CollusionDetector — Clears genuine organic user activity", () => {
  const candidate: LeaderboardCandidate = {
    user_id: "user-organic-champion",
    echo_earned_this_week: 75,
    rank: 1,
  };

  // Organic gifts sent to distinct people, none sent back in a tight loop
  const gifts: GiftTransactionRecord[] = [
    { id: "g30", sender_id: "user-organic-champion", recipient_id: "friend-alice", amount: 10, created_at: "2026-08-01T10:00:00Z" },
    { id: "g31", sender_id: "user-organic-champion", recipient_id: "friend-bob", amount: 10, created_at: "2026-08-02T10:00:00Z" },
    { id: "g32", sender_id: "friend-charlie", recipient_id: "user-organic-champion", amount: 15, created_at: "2026-08-03T10:00:00Z" },
  ];

  const profiles: UserProfileRecord[] = [
    { id: "user-organic-champion", created_at: "2026-01-01T00:00:00Z" },
    { id: "friend-alice", created_at: "2026-02-01T00:00:00Z" },
    { id: "friend-bob", created_at: "2026-03-01T00:00:00Z" },
    { id: "friend-charlie", created_at: "2026-04-01T00:00:00Z" },
  ];

  // Active user: 14 mood logs this week
  const result = evaluateUserCollusion(candidate, gifts, profiles, 14);

  assertEquals(result.flagged, false);
  assertEquals(result.action, "CLEAR");
  assertEquals(result.riskScore, 0);
  assertEquals(result.reasons.length, 0);
});
