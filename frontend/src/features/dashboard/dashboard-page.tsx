import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { supabase } from "../../lib/supabase";
import { useAuth } from "../../lib/auth-context";
import type { LogEntry, Insight } from "../../lib/types";
import { formatDate, moodToEmoji } from "../../lib/date";
import { HabitTrackerWidget } from "./components/habit-tracker-widget";
import { QuickCheckInWidget } from "./components/QuickCheckInWidget";
import { shareStreakCard } from "./streak-card-canvas";
import { predictTomorrowMood, type AnalyticsLogEntry } from "../analytics/analytics-helpers";

// ─────────────────────────────────────────────────────────────────────────────
// Weekly Digest Card
// ─────────────────────────────────────────────────────────────────────────────

type WeeklyDigestData = {
  avgMood: number;
  trendArrow: "up" | "down" | "flat";
  highestDay: { date: string; mood: number } | null;
  lowestDay: { date: string; mood: number } | null;
  topTags: string[];
  aiReflection: string | null;
  daysLogged: number;
};

async function fetchWeeklyDigestData(userId: string): Promise<WeeklyDigestData | null> {
  // Get last 7 days of logs
  const sevenDaysAgo = new Date();
  sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

  const { data: thisWeek } = await supabase
    .from("log_entries")
    .select("date, mood, habits, notes")
    .eq("user_id", userId)
    .gte("date", sevenDaysAgo.toISOString())
    .order("date", { ascending: true });

  if (!thisWeek || thisWeek.length < 3) return null;

  // Get previous week for trend
  const fourteenDaysAgo = new Date();
  fourteenDaysAgo.setDate(fourteenDaysAgo.getDate() - 14);

  const { data: prevWeek } = await supabase
    .from("log_entries")
    .select("mood")
    .eq("user_id", userId)
    .gte("date", fourteenDaysAgo.toISOString())
    .lt("date", sevenDaysAgo.toISOString());

  // Compute avg mood
  const moodValues = thisWeek.filter((l) => l.mood != null).map((l) => l.mood as number);
  const avgMood = moodValues.reduce((a, b) => a + b, 0) / moodValues.length;

  const prevMoodValues = (prevWeek ?? []).filter((l) => l.mood != null).map((l) => l.mood as number);
  const prevAvg = prevMoodValues.length > 0
    ? prevMoodValues.reduce((a, b) => a + b, 0) / prevMoodValues.length
    : null;

  const trendArrow: "up" | "down" | "flat" =
    prevAvg === null ? "flat"
    : avgMood - prevAvg > 0.2 ? "up"
    : avgMood - prevAvg < -0.2 ? "down"
    : "flat";

  // Highest / lowest days
  const sorted = [...thisWeek]
    .filter((l) => l.mood != null)
    .sort((a, b) => (b.mood as number) - (a.mood as number));
  const highestDay = sorted.length > 0 ? { date: sorted[0].date, mood: sorted[0].mood as number } : null;
  const lowestDay = sorted.length > 0 ? { date: sorted[sorted.length - 1].date, mood: sorted[sorted.length - 1].mood as number } : null;

  // Top habits / tags
  const habitCounts = new Map<string, number>();
  for (const log of thisWeek) {
    for (const h of (log.habits as string[]) ?? []) {
      habitCounts.set(h, (habitCounts.get(h) ?? 0) + 1);
    }
  }
  const topTags = [...habitCounts.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 4)
    .map(([name]) => name);

  // AI reflection (latest insight)
  const { data: insights } = await supabase
    .from("ai_insights")
    .select("prediction")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(1);

  const aiReflection =
    insights && insights.length > 0
      ? (insights[0] as { prediction: string }).prediction.slice(0, 160) +
        (insights[0].prediction.length > 160 ? "…" : "")
      : null;

  return {
    avgMood: Math.round(avgMood * 10) / 10,
    trendArrow,
    highestDay,
    lowestDay,
    topTags,
    aiReflection,
    daysLogged: thisWeek.length,
  };
}

function WeeklyDigestCard({
  userId,
  onDismiss,
}: {
  userId: string;
  onDismiss: () => void;
}) {
  const digestQuery = useQuery({
    queryKey: ["weekly-digest", userId],
    queryFn: () => fetchWeeklyDigestData(userId),
    staleTime: 1000 * 60 * 30,
  });

  if (digestQuery.isLoading) {
    return (
      <article className="card" style={{ gridColumn: "1 / -1" }}>
        <div className="card-header">
          <h3>📊 Your Week in Review</h3>
        </div>
        <div className="card-content">
          <div className="skeleton-line" style={{ maxWidth: "80%" }} />
          <div className="skeleton-line" style={{ maxWidth: "60%", marginTop: "0.5rem" }} />
        </div>
      </article>
    );
  }

  if (digestQuery.isError || !digestQuery.data) return null;

  const { avgMood, trendArrow, highestDay, lowestDay, topTags, aiReflection, daysLogged } =
    digestQuery.data;

  const trendSymbol = trendArrow === "up" ? "↑" : trendArrow === "down" ? "↓" : "→";
  const trendColor =
    trendArrow === "up" ? "var(--success)" : trendArrow === "down" ? "var(--danger)" : "var(--muted)";

  return (
    <article
      className="card"
      style={{ gridColumn: "1 / -1", borderLeft: "4px solid var(--brand)" }}
      aria-label="Weekly mood digest"
    >
      {/* Header */}
      <div className="card-header" style={{ alignItems: "flex-start" }}>
        <div>
          <h3 style={{ margin: 0 }}>📊 Your Week in Review</h3>
          <p className="muted" style={{ margin: "0.2rem 0 0", fontSize: "0.8rem" }}>
            {daysLogged} day{daysLogged !== 1 ? "s" : ""} logged this week
          </p>
        </div>
        <button
          type="button"
          aria-label="Dismiss weekly digest"
          onClick={onDismiss}
          style={{
            background: "none",
            border: "none",
            cursor: "pointer",
            color: "var(--muted)",
            fontSize: "1.1rem",
            lineHeight: 1,
            padding: "0.2rem 0.4rem",
            borderRadius: "4px",
          }}
        >
          ✕
        </button>
      </div>

      {/* Stats row */}
      <div
        className="card-content"
        style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(140px, 1fr))", gap: "0.75rem" }}
      >
        {/* Avg mood */}
        <div
          style={{
            background: "var(--surface-2, rgba(99,102,241,0.06))",
            borderRadius: "10px",
            padding: "0.85rem 1rem",
            textAlign: "center",
          }}
        >
          <div style={{ fontSize: "1.8rem", lineHeight: 1 }}>{moodToEmoji(Math.round(avgMood))}</div>
          <div style={{ fontWeight: 700, fontSize: "1.4rem", color: "var(--brand)", margin: "0.2rem 0 0" }}>
            {avgMood}
          </div>
          <div className="muted" style={{ fontSize: "0.7rem" }}>
            Avg mood{" "}
            <span style={{ color: trendColor, fontWeight: 700 }}>{trendSymbol}</span>
          </div>
        </div>

        {/* Best day */}
        {highestDay && (
          <div
            style={{
              background: "rgba(16,185,129,0.07)",
              borderRadius: "10px",
              padding: "0.85rem 1rem",
              textAlign: "center",
            }}
          >
            <div style={{ fontSize: "1.8rem", lineHeight: 1 }}>{moodToEmoji(highestDay.mood)}</div>
            <div style={{ fontWeight: 700, fontSize: "1.1rem", color: "var(--success)", margin: "0.2rem 0 0" }}>
              Best day
            </div>
            <div className="muted" style={{ fontSize: "0.7rem" }}>
              {formatDate(highestDay.date)}
            </div>
          </div>
        )}

        {/* Toughest day */}
        {lowestDay && lowestDay.date !== highestDay?.date && (
          <div
            style={{
              background: "rgba(239,68,68,0.06)",
              borderRadius: "10px",
              padding: "0.85rem 1rem",
              textAlign: "center",
            }}
          >
            <div style={{ fontSize: "1.8rem", lineHeight: 1 }}>{moodToEmoji(lowestDay.mood)}</div>
            <div style={{ fontWeight: 700, fontSize: "1.1rem", color: "var(--danger)", margin: "0.2rem 0 0" }}>
              Toughest day
            </div>
            <div className="muted" style={{ fontSize: "0.7rem" }}>
              {formatDate(lowestDay.date)}
            </div>
          </div>
        )}

        {/* Days logged */}
        <div
          style={{
            background: "rgba(139,92,246,0.07)",
            borderRadius: "10px",
            padding: "0.85rem 1rem",
            textAlign: "center",
          }}
        >
          <div style={{ fontSize: "1.8rem", lineHeight: 1 }}>📅</div>
          <div style={{ fontWeight: 700, fontSize: "1.4rem", color: "#8B5CF6", margin: "0.2rem 0 0" }}>
            {daysLogged}/7
          </div>
          <div className="muted" style={{ fontSize: "0.7rem" }}>Days logged</div>
        </div>
      </div>

      {/* Top habits */}
      {topTags.length > 0 && (
        <div style={{ padding: "0 1.25rem 0.75rem" }}>
          <p style={{ fontSize: "0.8rem", color: "var(--muted)", margin: "0 0 0.4rem", fontWeight: 600 }}>
            TOP HABITS
          </p>
          <div style={{ display: "flex", flexWrap: "wrap", gap: "0.4rem" }}>
            {topTags.map((tag) => (
              <span
                key={tag}
                className="chip"
                style={{ fontSize: "0.75rem", padding: "0.2rem 0.6rem" }}
              >
                {tag}
              </span>
            ))}
          </div>
        </div>
      )}

      {/* AI reflection */}
      {aiReflection && (
        <div
          style={{
            margin: "0 1.25rem 1rem",
            padding: "0.75rem 1rem",
            background: "linear-gradient(135deg, rgba(99,102,241,0.06), rgba(139,92,246,0.06))",
            borderRadius: "10px",
            borderLeft: "3px solid var(--brand)",
          }}
        >
          <p style={{ fontSize: "0.8rem", color: "var(--muted)", margin: "0 0 0.3rem", fontWeight: 600 }}>
            💡 AI REFLECTION
          </p>
          <p style={{ fontSize: "0.85rem", lineHeight: 1.55, margin: 0, color: "var(--text)" }}>
            {aiReflection}
          </p>
        </div>
      )}
    </article>
  );
}

async function fetchMoodTrend(userId: string) {
  const today = new Date();
  const lastWeek = new Date();
  lastWeek.setDate(today.getDate() - 7);

  const { data: thisWeekData, error: thisWeekError } = await supabase
    .from("log_entries")
    .select("date, mood")
    .eq("user_id", userId)
    .gte("date", lastWeek.toISOString())
    .order("date", { ascending: true });

  if (thisWeekError) throw thisWeekError;

  if (!thisWeekData || thisWeekData.length === 0) {
    return { currentAvg: null, previousAvg: null, thisWeekData: [] };
  }

  const currentAvg =
    thisWeekData.reduce((sum, log) => sum + (log.mood ?? 0), 0) /
    thisWeekData.length;

  // Get previous week data
  const twoWeeksAgo = new Date();
  twoWeeksAgo.setDate(today.getDate() - 14);

  const { data: prevWeekData, error: prevWeekError } = await supabase
    .from("log_entries")
    .select("mood")
    .eq("user_id", userId)
    .gte("date", twoWeeksAgo.toISOString())
    .lt("date", lastWeek.toISOString())
    .order("date", { ascending: true });

  if (prevWeekError) {
    // Return null for previousAvg on error so UI shows no comparison
    return { currentAvg, previousAvg: null, thisWeekData };
  }

  const previousAvg =
    prevWeekData.reduce((sum, log) => sum + (log.mood ?? 0), 0) /
    prevWeekData.length;

  return { currentAvg, previousAvg, thisWeekData };
}

export function DashboardPage() {
  const { user } = useAuth();
  const navigate = useNavigate();

  // Streak query
  const streakQuery = useQuery({
    queryKey: ["dashboard-streak", user?.id],
    queryFn: async () => {
      if (!user) return 0;
      const { data, error } = await supabase.rpc("get_current_streak", {
        user_id: user.id,
      });
      if (error) throw error;
      return Number(data ?? 0);
    },
    enabled: !!user,
  });

  // Recent logs query (last 5)
  const recentLogsQuery = useQuery({
    queryKey: ["logs", user?.id],
    queryFn: async () => {
      if (!user) return [];
      const { data, error } = await supabase
        .from("log_entries")
        .select("id, date, mood, notes")
        .eq("user_id", user.id)
        .order("date", { ascending: false })
        .limit(5);
      if (error) throw error;
      return data as LogEntry[];
    },
    enabled: !!user,
  });

  // AI insight query
  const insightQuery = useQuery({
    queryKey: ["dashboard-insight", user?.id],
    queryFn: async () => {
      if (!user) return null;
      const { data, error } = await supabase
        .from("ai_insights")
        .select("id, prediction, created_at")
        .eq("user_id", user.id)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      if (error) throw error;
      return data as Insight | null;
    },
    enabled: !!user,
  });

  const moodTrendQuery = useQuery({
    queryKey: ["dashboard-mood-trend", user?.id],
    queryFn: () => fetchMoodTrend(user!.id),
    enabled: !!user,
  });

  // Mood prediction query
  const predictionQuery = useQuery({
    queryKey: ["dashboard-prediction", user?.id],
    queryFn: async () => {
      if (!user) return null;
      const sixtyDaysAgo = new Date();
      sixtyDaysAgo.setDate(sixtyDaysAgo.getDate() - 60);
      const { data, error } = await supabase
        .from("log_entries")
        .select("id, date, mood, habits, notes, user_id, created_at, updated_at")
        .eq("user_id", user.id)
        .gte("date", sixtyDaysAgo.toISOString())
        .order("date", { ascending: true });
      if (error) throw error;
      const entries = (data ?? []).map((e) => ({
        ...e,
        habits: Array.isArray(e.habits) ? e.habits : [],
      })) as AnalyticsLogEntry[];
      if (entries.length < 14) return null;
      return predictTomorrowMood(entries);
    },
    enabled: !!user,
    staleTime: 1000 * 60 * 60 * 12,
  });

  // Streak freeze query
  const freezeQuery = useQuery({
    queryKey: ["streak-freeze", user?.id],
    queryFn: async () => {
      if (!user) return null;
      const today = new Date().toISOString().slice(0, 10);
      const tomorrow = new Date(Date.now() + 86400000).toISOString().slice(0, 10);
      const { data, error } = await supabase
        .from("streak_freezes")
        .select("id, used_on_date")
        .eq("user_id", user.id)
        .in("used_on_date", [today, tomorrow])
        .maybeSingle();
      if (error) throw error;
      return data as { id: string; used_on_date: string } | null;
    },
    enabled: !!user,
  });

  const queryClient = useQueryClient();
  const [showFreezeModal, setShowFreezeModal] = useState(false);
  const [isSharingStreak, setIsSharingStreak] = useState(false);

  // Weekly digest card dismissal — persisted in sessionStorage so it resets each session
  const DIGEST_DISMISS_KEY = "weekly-digest-dismissed";
  const [digestDismissed, setDigestDismissed] = useState<boolean>(() => {
    try {
      return sessionStorage.getItem(DIGEST_DISMISS_KEY) === "1";
    } catch {
      return false;
    }
  });

  const handleDismissDigest = () => {
    try {
      sessionStorage.setItem(DIGEST_DISMISS_KEY, "1");
    } catch {
      // ignore
    }
    setDigestDismissed(true);
  };

  const purchaseFreezeMutation = useMutation({
    mutationFn: async () => {
      if (!user) throw new Error("Not authenticated");
      const tomorrow = new Date(Date.now() + 86400000).toISOString().slice(0, 10);
      const { error } = await supabase.from("streak_freezes").insert({
        user_id: user.id,
        used_on_date: tomorrow,
        echo_cost: 5,
        created_at: new Date().toISOString(),
      });
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["streak-freeze", user?.id] });
      queryClient.invalidateQueries({ queryKey: ["dashboard-echo", user?.id] });
      setShowFreezeModal(false);
    },
  });

  const echoQuery = useQuery({
    queryKey: ["dashboard-echo", user?.id],
    queryFn: async () => {
      if (!user) return { balance: 0, earnedToday: 0 };

      const walletRes = await supabase
        .from("user_wallets")
        .select("balance")
        .eq("user_id", user.id)
        .maybeSingle();

      const balance =
        walletRes.data && typeof (walletRes.data as Record<string, unknown>).balance === "number"
          ? Number((walletRes.data as Record<string, unknown>).balance)
          : 0;

      const today = new Date().toISOString().slice(0, 10);
      const { data: rewards } = await supabase
        .from("echo_rewards")
        .select("amount")
        .eq("user_id", user.id)
        .gte("created_at", today);

      const earnedToday =
        (rewards ?? []).reduce(
          (sum: number, r: Record<string, unknown>) => sum + Number(r.amount ?? 0),
          0,
        );

      return { balance, earnedToday };
    },
    enabled: !!user,
  });

  const currentStreak = streakQuery.data ?? 0;

  const currentAvg = moodTrendQuery.data?.currentAvg ?? 0;
  const previousAvg = moodTrendQuery.data?.previousAvg ?? null;
  const percentageChange =
    previousAvg && previousAvg > 0
      ? ((currentAvg - previousAvg) / previousAvg) * 100
      : null;

  if (!user) {
    return null;
  }

  const echoData = echoQuery.data ?? { balance: 0, earnedToday: 0 };

  const handleShareStreak = async () => {
    if (isSharingStreak || currentStreak <= 0) return;
    setIsSharingStreak(true);
    try {
      await shareStreakCard({ streak: currentStreak });
    } catch (error) {
      console.error("Failed to share streak card", error);
    } finally {
      setIsSharingStreak(false);
    }
  };

  return (
    <section className="feature-grid">
      {/* Quick Check-in Widget */}
      <div style={{ gridColumn: '1 / -1' }}>
        <QuickCheckInWidget />
      </div>

      {/* Weekly Mood Digest Card — shown on Mondays, dismissible, requires ≥3 logs */}
      {!digestDismissed && (
        <WeeklyDigestCard userId={user.id} onDismiss={handleDismissDigest} />
      )}

      {/* Mood Summary Card - spans 2 columns */}
      <article className="card">
        <div className="card-header">
          <h3>Mood Summary</h3>
        </div>
        <div className="card-content">
          {moodTrendQuery.isLoading ? (
            <div className="skeleton-line large" />
          ) : (
            <div style={{ display: "flex", alignItems: "center", gap: "1.5rem" }}>
              <div>
                <p className="muted">Today's Mood</p>
                <h2 style={{ margin: "0.25rem 0" }}>
                  {currentAvg.toFixed(1)} / 5
                </h2>
                {percentageChange !== null && (
                  <p
                    style={{
                      margin: "0.25rem 0 0",
                      color:
                        percentageChange > 0 ? "var(--success)" : "var(--danger)",
                      fontWeight: 600,
                    }}
                  >
                    {percentageChange > 0 ? "↑" : "↓"}{" "}
                    {Math.abs(percentageChange).toFixed(1)}% vs last week
                  </p>
                )}
              </div>
              <div
                style={{
                  flex: 1,
                  minHeight: "80px",
                  minWidth: "120px",
                }}
              >
                <MoodSparkline logs={moodTrendQuery.data?.thisWeekData ?? []} />
              </div>
            </div>
          )}
        </div>
      </article>

      {/* Streak Card */}
      <article className="card">
        <div className="card-header">
          <h3>Streak</h3>
          {freezeQuery.data && (
            <span
              className="chip"
              style={{
                fontSize: "0.7rem",
                background: "var(--brand)",
                color: "#fff",
                border: "none",
              }}
            >
              ❄️ Streak protected
            </span>
          )}
        </div>
        <div className="card-content">
          {streakQuery.isLoading ? (
            <div style={{ display: "grid", gap: "0.65rem" }} aria-label="Loading streak">
              <div className="skeleton-line large" style={{ maxWidth: "190px" }} />
              <div className="skeleton-line" style={{ maxWidth: "260px" }} />
            </div>
          ) : streakQuery.isError ? (
            <p className="muted">Streak unavailable right now.</p>
          ) : currentStreak > 0 ? (
            <div className="streak-count">
              <p className="muted">Current streak</p>
              <h2 style={{ margin: "0.25rem 0 0" }}>🔥 {currentStreak}-day streak</h2>
              <div style={{ display: "flex", flexWrap: "wrap", gap: "0.5rem", marginTop: "0.75rem" }}>
                <button
                  type="button"
                  onClick={handleShareStreak}
                  disabled={isSharingStreak}
                  style={{
                    background: "var(--brand)",
                    border: "1px solid var(--brand)",
                    color: "#fff",
                    borderRadius: "8px",
                    padding: "0.35rem 0.75rem",
                    fontSize: "0.8rem",
                    cursor: isSharingStreak ? "default" : "pointer",
                    opacity: isSharingStreak ? 0.7 : 1,
                  }}
                >
                  {isSharingStreak ? "Preparing…" : "↗ Share streak"}
                </button>
                {currentStreak >= 3 && !freezeQuery.data && echoQuery.data && (echoQuery.data as { balance: number; earnedToday: number }).balance >= 10 && (
                  <button
                    type="button"
                    onClick={() => setShowFreezeModal(true)}
                    style={{
                      background: "none",
                      border: "1px solid var(--brand)",
                      color: "var(--brand)",
                      borderRadius: "8px",
                      padding: "0.35rem 0.75rem",
                      fontSize: "0.8rem",
                      cursor: "pointer",
                    }}
                  >
                    ❄️ Protect my streak (5 ECHO)
                  </button>
                )}
              </div>
            </div>
          ) : (
            <div className="streak-count">
              <h2 style={{ margin: "0 0 0.3rem" }}>Start your streak today</h2>
              <p className="muted" style={{ margin: 0 }}>
                Log your mood today to begin building momentum.
              </p>
            </div>
          )}
        </div>
      </article>

      {/* Freeze confirmation modal */}
      {showFreezeModal && (
        <div
          style={{
            position: "fixed",
            inset: 0,
            zIndex: 1000,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            background: "rgba(0,0,0,0.5)",
          }}
          onClick={() => setShowFreezeModal(false)}
        >
          <div
            className="card"
            style={{ maxWidth: "380px", width: "90%", margin: 0 }}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="card-header">
              <h3>Protect your streak</h3>
            </div>
            <div className="card-content">
              <p style={{ marginBottom: "1rem", lineHeight: 1.6 }}>
                Spend <strong>5 ECHO</strong> to freeze tomorrow's streak? You'll
                keep your streak even if you don't log.
              </p>
              <div style={{ display: "flex", gap: "0.75rem" }}>
                <button
                  type="button"
                  className="btn"
                  onClick={() => setShowFreezeModal(false)}
                  style={{ flex: 1 }}
                >
                  Cancel
                </button>
                <button
                  type="button"
                  className="btn btn-primary"
                  onClick={() => purchaseFreezeMutation.mutate()}
                  disabled={purchaseFreezeMutation.isPending}
                  style={{ flex: 1 }}
                >
                  {purchaseFreezeMutation.isPending ? "Freezing..." : "❄️ Freeze it"}
                </button>
              </div>
              {purchaseFreezeMutation.isError && (
                <p style={{ color: "var(--danger)", marginTop: "0.75rem", fontSize: "0.85rem" }}>
                  Failed to freeze streak. Please try again.
                </p>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Tomorrow's Forecast Card */}
      {predictionQuery.data && (
        <article className="card">
          <div className="card-header">
            <h3>Tomorrow's forecast</h3>
          </div>
          <div className="card-content">
            <div style={{ display: "flex", alignItems: "center", gap: "0.75rem" }}>
              <span style={{ fontSize: "2rem" }}>
                {moodToEmoji(Math.round(predictionQuery.data.predicted))}
              </span>
              <div>
                <h2 style={{ margin: 0 }}>
                  {predictionQuery.data.predicted.toFixed(1)} / 5
                </h2>
                <p className="muted" style={{ margin: "0.15rem 0 0", fontSize: "0.8rem" }}>
                  {predictionQuery.data.reason}
                </p>
              </div>
            </div>
            <div style={{ marginTop: "0.5rem" }}>
              <span
                className="chip"
                style={{
                  fontSize: "0.7rem",
                  padding: "0.15rem 0.5rem",
                  background:
                    predictionQuery.data.confidence === "high"
                      ? "var(--success)"
                      : predictionQuery.data.confidence === "medium"
                        ? "var(--warning)"
                        : "var(--muted)",
                  color: "#fff",
                  border: "none",
                }}
              >
                {predictionQuery.data.confidence} confidence
              </span>
            </div>
          </div>
        </article>
      )}

      {/* ECHO Balance Card */}
      <article
        className="card"
        style={{ cursor: "pointer" }}
        onClick={() => navigate("/wallet")}
      >
        <div className="card-header">
          <h3>ECHO Balance</h3>
        </div>
        <div className="card-content">
          {echoQuery.isLoading ? (
            <p className="muted">Loading…</p>
          ) : echoQuery.isError ? (
            <p className="muted">Failed to load balance.</p>
          ) : (
            <>
              <h2>
                ✦ {echoData.balance.toFixed(0)} ECHO
              </h2>
              {echoData.earnedToday > 0 && (
                <p className="muted" style={{ marginTop: "0.25rem" }}>
                  +{echoData.earnedToday} today
                </p>
              )}
              <p className="muted" style={{ marginTop: "0.5rem", fontSize: "0.8rem" }}>
                Tap to view wallet →
              </p>
            </>
          )}
        </div>
      </article>

      {/* Habit Tracker Widget */}
      <HabitTrackerWidget />

      {/* Recent Logs List */}
      <article className="card">
        <div className="card-header">
          <h3>Recent Logs</h3>
          <button
            type="button"
            onClick={() => navigate("/logs")}
            style={{
              background: "none",
              border: "none",
              color: "var(--brand)",
              cursor: "pointer",
              fontSize: "0.85rem",
            }}
          >
            View all
          </button>
        </div>
        <div className="card-content">
          {(recentLogsQuery.isLoading || streakQuery.isLoading) && (
            <p className="muted">Loading…</p>
          )}
          {recentLogsQuery.data && recentLogsQuery.data.length === 0 && (
            <div className="muted">
              <p>No logs yet</p>
              <button
                type="button"
                onClick={() => navigate("/logs/new")}
                style={{
                  background: "none",
                  border: "none",
                  color: "var(--brand)",
                  cursor: "pointer",
                  fontSize: "0.85rem",
                  marginTop: "0.25rem",
                  padding: 0,
                }}
              >
                Create your first log →
              </button>
            </div>
          )}
          {recentLogsQuery.data && recentLogsQuery.data.length > 0 && (
            <div className="list-card">
              {recentLogsQuery.data.map((log) => (
                <div
                  key={log.id}
                  className="list-item"
                  onClick={() => navigate(`/logs/${log.id}/edit`)}
                  style={{
                    cursor: "pointer",
                    padding: "0.5rem 0",
                    borderBottom: "1px solid var(--line)",
                  }}
                >
                  <span className="muted">
                    {formatDate(log.date)}
                  </span>
                  <span>{moodToEmoji(log.mood)}</span>
                  <span className="muted">
                    {log.notes ? log.notes.substring(0, 80) : "No notes"}
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>
      </article>

      {/* AI Insight Preview */}
      <article className="card">
        <div className="card-header">
          <h3>Latest Insight</h3>
        </div>
        <div className="card-content">
          {insightQuery.isLoading && <p className="muted">Loading…</p>}
          {insightQuery.data ? (
            <>
              <p style={{ marginBottom: "0.75rem" }}>
                {insightQuery.data.prediction.substring(0, 150)}
                {insightQuery.data.prediction.length > 150 ? "…" : ""}
              </p>
              <button
                type="button"
                onClick={() => navigate("/insights")}
                style={{
                  background: "none",
                  border: "none",
                  color: "var(--brand)",
                  cursor: "pointer",
                  fontSize: "0.9rem",
                  fontWeight: 600,
                }}
              >
                View full analysis →
              </button>
            </>
          ) : (
            <>
              <p className="muted">No insights yet</p>
              <p className="muted" style={{ fontSize: "0.8rem", marginTop: "0.25rem" }}>
                Insights are generated after you log a few entries
              </p>
              <button
                type="button"
                onClick={() => navigate("/insights")}
                style={{
                  background: "none",
                  border: "none",
                  color: "var(--brand)",
                  cursor: "pointer",
                  fontSize: "0.9rem",
                  fontWeight: 600,
                  marginTop: "0.5rem",
                }}
              >
                View insights page
              </button>
            </>
          )}
        </div>
      </article>

    </section>
  );
}

// Simple sparkline component for mood trend
function MoodSparkline({ logs }: { logs: Array<{ date: string; mood: number | null }> }) {
  if (!logs || logs.length === 0) {
    return (
      <div
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          height: "80px",
          color: "var(--muted)",
          fontSize: "0.85rem",
        }}
      >
        No trend data
      </div>
    );
  }

  // Create sparkline SVG
  const moodValues = logs.map((log) => log.mood ?? 0);
  const minMood = 0;
  const maxMood = 5;
  const width = 120;
  const height = 80;

  // Handle single data point case
  if (moodValues.length < 2) {
    const x = width / 2;
    const y = height - ((moodValues[0] - minMood) / (maxMood - minMood)) * height;
    return (
      <svg
        width="100%"
        height="100%"
        viewBox={`0 0 ${width} ${height}`}
        preserveAspectRatio="none"
        style={{ overflow: "visible" }}
      >
        <circle
          cx={x}
          cy={y}
          r="3"
          fill="var(--brand)"
          stroke="white"
          strokeWidth="1"
        />
      </svg>
    );
  }

  const points = moodValues.map((mood, index) => {
    const x = (index / (moodValues.length - 1)) * width;
    const y = height - ((mood - minMood) / (maxMood - minMood)) * height;
    return `${x},${y}`;
  });

  return (
    <svg
      width="100%"
      height="100%"
      viewBox={`0 0 ${width} ${height}`}
      preserveAspectRatio="none"
      style={{ overflow: "visible" }}
    >
      <polyline
        points={points.join(" ")}
        fill="none"
        stroke="var(--brand)"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      {moodValues.map((mood, index) => {
        const x = (index / (moodValues.length - 1)) * width;
        const y = height - ((mood - minMood) / (maxMood - minMood)) * height;
        return (
          <circle
            key={index}
            cx={x}
            cy={y}
            r="3"
            fill="var(--brand)"
            stroke="white"
            strokeWidth="1"
          />
        );
      })}
    </svg>
  );
}
