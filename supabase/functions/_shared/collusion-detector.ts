// Issue #701: Detect leaderboard/gift collusion before real ECHO payouts settle

export interface LeaderboardCandidate {
  id?: string;
  user_id: string;
  echo_earned_this_week: number;
  rank: number;
  created_at?: string;
}

export interface GiftTransactionRecord {
  id: string;
  sender_id: string;
  recipient_id: string;
  amount: number;
  created_at: string;
}

export interface UserProfileRecord {
  id: string;
  created_at: string;
}

export interface CollusionAuditResult {
  userId: string;
  rank: number;
  flagged: boolean;
  riskScore: number; // 0 to 100
  reasons: string[];
  action: 'WITHHOLD_FOR_REVIEW' | 'CLEAR';
  evidence: {
    reciprocityRatio: number;
    closedLoopPartners: string[];
    creationClusterAccounts: string[];
    moodLogsCount: number;
    echoEarnedThisWeek: number;
  };
}

export interface CollusionDetectorOptions {
  reciprocityThreshold?: number; // e.g. 0.70 (70% reciprocal gift volume)
  creationClusterWindowMinutes?: number; // e.g. 60 minutes
  minGiftsForReciprocityCheck?: number; // e.g. 3 gifts
  minEchoForVelocityCheck?: number; // e.g. 50 ECHO
}

/**
 * Pure evaluation function for analyzing collusion signals across candidate activity.
 */
export function evaluateUserCollusion(
  candidate: LeaderboardCandidate,
  allGifts: GiftTransactionRecord[],
  allProfiles: UserProfileRecord[],
  userMoodLogsCount: number,
  options: CollusionDetectorOptions = {}
): CollusionAuditResult {
  const {
    reciprocityThreshold = 0.7,
    creationClusterWindowMinutes = 60,
    minGiftsForReciprocityCheck = 3,
    minEchoForVelocityCheck = 50,
  } = options;

  const reasons: string[] = [];
  let riskScore = 0;

  const userId = candidate.user_id;

  // --- Signal 1: Gift-Graph Reciprocity & Closed Loops ---
  // Look for gifts sent and received by this user
  const sentGifts = allGifts.filter((g) => g.sender_id === userId);
  const receivedGifts = allGifts.filter((g) => g.recipient_id === userId);

  const totalGiftsCount = sentGifts.length + receivedGifts.length;
  const totalGiftVolume =
    sentGifts.reduce((acc, g) => acc + g.amount, 0) +
    receivedGifts.reduce((acc, g) => acc + g.amount, 0);

  let reciprocalVolume = 0;
  const closedLoopPartners: string[] = [];

  if (totalGiftsCount >= minGiftsForReciprocityCheck && totalGiftVolume > 0) {
    const sentTo = new Map<string, number>();
    for (const g of sentGifts) {
      sentTo.set(g.recipient_id, (sentTo.get(g.recipient_id) ?? 0) + g.amount);
    }

    const receivedFrom = new Map<string, number>();
    for (const g of receivedGifts) {
      receivedFrom.set(g.sender_id, (receivedFrom.get(g.sender_id) ?? 0) + g.amount);
    }

    // Identify partners with two-way gifting
    for (const [partnerId, sentAmt] of sentTo.entries()) {
      const receivedAmt = receivedFrom.get(partnerId) ?? 0;
      if (receivedAmt > 0) {
        reciprocalVolume += sentAmt + receivedAmt;
        closedLoopPartners.push(partnerId);
      }
    }

    const reciprocityRatio = reciprocalVolume / totalGiftVolume;

    if (reciprocityRatio >= reciprocityThreshold) {
      riskScore += 45;
      reasons.push(
        `High gift-loop reciprocity: ${(reciprocityRatio * 100).toFixed(
          0
        )}% of gift volume cycled with partner(s): ${closedLoopPartners.join(', ')}`
      );
    }
  }

  const calculatedReciprocityRatio =
    totalGiftVolume > 0 ? reciprocalVolume / totalGiftVolume : 0;

  // --- Signal 2: Account-Creation Clustering ---
  const creationClusterAccounts: string[] = [];
  const candidateProfile = allProfiles.find((p) => p.id === userId);

  if (candidateProfile && closedLoopPartners.length > 0) {
    const candidateCreatedAt = new Date(candidateProfile.created_at).getTime();

    for (const partnerId of closedLoopPartners) {
      const partnerProfile = allProfiles.find((p) => p.id === partnerId);
      if (partnerProfile) {
        const partnerCreatedAt = new Date(partnerProfile.created_at).getTime();
        const diffMinutes =
          Math.abs(candidateCreatedAt - partnerCreatedAt) / (1000 * 60);

        if (diffMinutes <= creationClusterWindowMinutes) {
          creationClusterAccounts.push(partnerId);
        }
      }
    }

    if (creationClusterAccounts.length > 0) {
      riskScore += 35;
      reasons.push(
        `Account creation clustering: created within ${creationClusterWindowMinutes}m of active gifting partner(s) [${creationClusterAccounts.join(
          ', '
        )}]`
      );
    }
  }

  // --- Signal 3: Velocity & Activity Mismatch ---
  if (
    candidate.echo_earned_this_week >= minEchoForVelocityCheck &&
    userMoodLogsCount <= 1 &&
    receivedGifts.length >= 2
  ) {
    riskScore += 30;
    reasons.push(
      `Velocity anomaly: high earnings (${candidate.echo_earned_this_week} ECHO) with negligible core logging activity (${userMoodLogsCount} mood logs)`
    );
  }

  const flagged = riskScore >= 50;
  const action = flagged ? 'WITHHOLD_FOR_REVIEW' : 'CLEAR';

  return {
    userId,
    rank: candidate.rank,
    flagged,
    riskScore: Math.min(riskScore, 100),
    reasons,
    action,
    evidence: {
      reciprocityRatio: calculatedReciprocityRatio,
      closedLoopPartners,
      creationClusterAccounts,
      moodLogsCount: userMoodLogsCount,
      echoEarnedThisWeek: candidate.echo_earned_this_week,
    },
  };
}

/**
 * Audits a list of leaderboard candidates before ECHO payout.
 */
export async function auditLeaderboardCollusion(
  supabase: any,
  candidates: LeaderboardCandidate[],
  options?: CollusionDetectorOptions
): Promise<Map<string, CollusionAuditResult>> {
  const results = new Map<string, CollusionAuditResult>();
  if (!candidates || candidates.length === 0) return results;

  const userIds = candidates.map((c) => c.user_id);

  // Fetch recent gifts for all candidates
  const { data: giftsData } = await supabase
    .from('gift_transactions')
    .select('id, sender_id, recipient_id, amount, created_at')
    .or(`sender_id.in.(${userIds.join(',')}),recipient_id.in.(${userIds.join(',')})`);

  const allGifts: GiftTransactionRecord[] = giftsData ?? [];

  // Fetch profile creation dates
  const { data: profilesData } = await supabase
    .from('profiles')
    .select('id, created_at');

  const allProfiles: UserProfileRecord[] = profilesData ?? [];

  // Fetch mood logs for candidates for velocity check
  const moodLogsCountMap = new Map<string, number>();
  for (const userId of userIds) {
    const { count } = await supabase
      .from('log_entries')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId);
    moodLogsCountMap.set(userId, count ?? 0);
  }

  for (const candidate of candidates) {
    const auditResult = evaluateUserCollusion(
      candidate,
      allGifts,
      allProfiles,
      moodLogsCountMap.get(candidate.user_id) ?? 0,
      options
    );
    results.set(candidate.user_id, auditResult);
  }

  return results;
}
