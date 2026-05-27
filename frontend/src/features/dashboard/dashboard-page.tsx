import { useQuery } from "@tanstack/react-query";
import { useNavigate } from "react-router-dom";
import { supabase } from "../../lib/supabase";
import { useAuth } from "../../lib/auth-context";
import type { LogEntry } from "../../lib/types";
import { formatDate, moodToEmoji } from "../../lib/date";
import { HabitTrackerWidget } from "./components/habit-tracker-widget";
import { MoodChartWidget } from "./components/mood-chart-widget";

export function DashboardPage() {
  const { user } = useAuth();
  const navigate = useNavigate();

  const streakQuery = useQuery({
    queryKey: ["dashboard-streak", user?.id],
    queryFn: async () => {
      if (!user)
        return { current_streak: 0, longest_streak: 0, last_log_date: null };
      const { data, error } = await supabase.rpc("calculate_streak", {
        p_user_id: user.id,
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

  const recentLogsQuery = useQuery({
    queryKey: ["logs", user?.id],
    queryFn: async () => {
      if (!user) return [];
      const { data, error } = await supabase
        .from("log_entries")
        .select("id, date, mood, notes")
        .eq("user_id", user.id)
        .order("date", { ascending: false })
        .limit(3);
      if (error) throw error;
      return data as LogEntry[];
    },
    enabled: !!user,
  });

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
      return data;
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

  if (!user) {
    return null;
  }

  const echoData = echoQuery.data ?? { balance: 0, earnedToday: 0 };

  return (
    <section className="feature-grid">
      {/* Mood Chart - spans 2 columns */}
      <MoodChartWidget />

      {/* Mood Streak Card */}
      <article className="card">
        <div className="card-header">
          <h3>Mood Streak</h3>
        </div>
        <div className="card-content">
          <div
            className="streak-count"
            style={{ display: "flex", gap: "2rem" }}
          >
            <div>
              <p className="muted">Current streak</p>
              <h2>{streakData.current_streak} days</h2>
            </div>
            <div>
              <p className="muted">Longest streak</p>
              <h2>{streakData.longest_streak} days</h2>
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

      {/* Recent Logs Card */}
      <article className="card">
        <div className="card-header">
          <h3>Recent Logs</h3>
        </div>
        <div className="card-content">
          {recentLogsQuery.isLoading && <p className="muted">Loading…</p>}
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
                  style={{ cursor: "pointer" }}
                >
                  <span className="muted">
                    {formatDate(new Date(log.date))}
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

      {/* AI Insight Card */}
      <article className="card">
        <div className="card-header">
          <h3>Latest Insight</h3>
        </div>
        <div className="card-content">
          {insightQuery.isLoading && <p className="muted">Loading…</p>}
          {insightQuery.data ? (
            <>
              <p>{insightQuery.data.prediction.substring(0, 200)}</p>
              <button type="button" onClick={() => navigate("/insights")}>
                View full insight
              </button>
            </>
          ) : (
            <>
              <p className="muted">No insights yet</p>
              <button type="button" onClick={() => navigate("/insights")}>
                Generate insights
              </button>
            </>
          )}
        </div>
      </article>
    </section>
  );
}
