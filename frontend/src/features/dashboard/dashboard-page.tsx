import { useQuery } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { supabase } from "../../lib/supabase";
import { useAuth } from "../../lib/auth-context";
import type { LogEntry, Insight } from "../../lib/types";
import { formatDate, moodToEmoji } from "../../lib/date";
import { HabitTrackerWidget } from "./components/habit-tracker-widget";
import { MoodChartWidget } from "./components/mood-chart-widget";

// Fetch wallet balance
async function fetchWalletBalance(userId: string): Promise<number> {
  const { data, error } = await supabase
    .from("user_wallets")
    .select("balance")
    .eq("user_id", userId)
    .maybeSingle();

  if (error) throw error;
  return data?.balance ?? 0;
}

// Fetch mood trend for percentage calculation
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
      if (!user)
        return { current_streak: 0, longest_streak: 0, last_log_date: null };
      const { data, error } = await supabase.rpc("get_current_streak", {
        user_id: user.id,
      });
      if (error) throw error;
      return (data ?? {
        current_streak: 0,
        longest_streak: 0,
        last_log_date: null,
      }) as {
        current_streak: number;
        longest_streak: number;
        last_log_date: string | null;
      };
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

  const streakData = streakQuery.data ?? {
    current_streak: 0,
    longest_streak: 0,
    last_log_date: null,
  };

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

  return (
    <section className="feature-grid">
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
        </div>
        <div className="card-content">
          <div
            className="streak-count"
            style={{ display: "flex", gap: "1.5rem" }}
          >
            <div>
              <p className="muted">Current</p>
              <h2>{streakData.current_streak} days</h2>
            </div>
            <div>
              <p className="muted">Best</p>
              <h2>{streakData.longest_streak} days</h2>
            </div>
            <div>
              <p className="muted">Last logged</p>
              <p style={{ margin: "0.25rem 0 0", fontSize: "0.9rem" }}>
                {streakData.last_log_date
                  ? formatDate(new Date(streakData.last_log_date))
                  : "Never"}
              </p>
            </div>
          </div>
        </div>
      </article>

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
            <p className="muted">No logs yet</p>
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
                  <div
                    style={{
                      display: "flex",
                      justifyContent: "space-between",
                      alignItems: "center",
                    }}
                  >
                    <span className="muted" style={{ fontSize: "0.85rem" }}>
                      {formatDate(new Date(log.date))}
                    </span>
                    <span style={{ fontSize: "1.25rem" }}>
                      {moodToEmoji(log.mood)}
                    </span>
                  </div>
                  {log.notes && (
                    <p
                      style={{
                        margin: "0.25rem 0 0",
                        fontSize: "0.85rem",
                        color: "var(--muted)",
                      }}
                    >
                      {log.notes.substring(0, 60)}
                      {log.notes.length > 60 ? "…" : ""}
                    </p>
                  )}
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
                Generate insights
              </button>
            </>
          )}
        </div>
      </article>

      {/* ECHO Balance Chip */}
      <article className="card">
        <div className="card-header">
          <h3>ECHO Balance</h3>
        </div>
        <div className="card-content">
          {walletQuery.isLoading ? (
            <div className="skeleton-line large" />
          ) : (
            <div
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
              }}
            >
              <div>
                <p className="muted" style={{ margin: 0 }}>
                  Your balance
                </p>
                <h2 style={{ margin: "0.25rem 0 0", fontSize: "1.5rem" }}>
                  {walletQuery.data?.toFixed(2) ?? 0} ECHO
                </h2>
              </div>
              <button
                type="button"
                onClick={() => navigate("/wallet")}
                style={{
                  padding: "0.5rem 1rem",
                  fontSize: "0.85rem",
                }}
              >
                View wallet
              </button>
            </div>
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
