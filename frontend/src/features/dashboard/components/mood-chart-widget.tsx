import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { supabase } from "@/lib/supabase";
import { useAuth } from "@/lib/auth-context";

interface MoodLog {
  date: string;
  mood: number;
}

type Period = 7 | 30;

export function MoodChartWidget() {
  const { user } = useAuth();
  const [period, setPeriod] = useState<Period>(7);

  const moodDataQuery = useQuery({
    queryKey: ["mood-chart", user?.id, period],
    queryFn: async () => {
      if (!user) return [];

      const startDate = new Date();
      startDate.setDate(startDate.getDate() - period);

      const { data, error } = await supabase
        .from("log_entries")
        .select("date, mood")
        .eq("user_id", user.id)
        .gte("date", startDate.toISOString())
        .order("date", { ascending: true });

      if (error) throw error;

      // Transform data for recharts
      return (data as MoodLog[]).map((log) => ({
        date: new Date(log.date).toLocaleDateString("en-US", {
          month: "short",
          day: "numeric",
        }),
        mood: log.mood,
      }));
    },
    enabled: !!user,
  });

  const chartData = moodDataQuery.data ?? [];

  return (
    <article className="card" style={{ gridColumn: "span 2" }}>
      <div className="card-header">
        <h3>Mood Trend</h3>
        <div style={{ display: "flex", gap: "0.5rem" }}>
          <button
            type="button"
            onClick={() => setPeriod(7)}
            style={{
              padding: "0.25rem 0.75rem",
              background: period === 7 ? "#1463ff" : "transparent",
              color: period === 7 ? "white" : "inherit",
              border: "1px solid #1463ff",
              borderRadius: "4px",
              cursor: "pointer",
              fontSize: "0.875rem",
            }}
          >
            7 days
          </button>
          <button
            type="button"
            onClick={() => setPeriod(30)}
            style={{
              padding: "0.25rem 0.75rem",
              background: period === 30 ? "#1463ff" : "transparent",
              color: period === 30 ? "white" : "inherit",
              border: "1px solid #1463ff",
              borderRadius: "4px",
              cursor: "pointer",
              fontSize: "0.875rem",
            }}
          >
            30 days
          </button>
        </div>
      </div>
      <div className="card-content">
        {moodDataQuery.isLoading && <p className="muted">Loading mood data…</p>}

        {!moodDataQuery.isLoading && chartData.length === 0 && (
          <div style={{ textAlign: "center", padding: "2rem" }}>
            <p className="muted">No mood logs yet for this period.</p>
            <p className="muted" style={{ marginTop: "0.5rem" }}>
              Start logging your mood to see your emotional patterns!
            </p>
          </div>
        )}

        {chartData.length > 0 && (
          <ResponsiveContainer width="100%" height={300}>
            <AreaChart
              data={chartData}
              margin={{ top: 10, right: 10, left: 0, bottom: 0 }}
            >
              <defs>
                <linearGradient id="moodGradient" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#1463ff" stopOpacity={0.8} />
                  <stop offset="100%" stopColor="#14b8a6" stopOpacity={0.2} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
              <XAxis dataKey="date" tick={{ fontSize: 12 }} stroke="#6b7280" />
              <YAxis
                domain={[0, 5]}
                ticks={[0, 1, 2, 3, 4, 5]}
                tick={{ fontSize: 12 }}
                stroke="#6b7280"
                label={{
                  value: "Mood",
                  angle: -90,
                  position: "insideLeft",
                  style: { fontSize: 12 },
                }}
              />
              <Tooltip
                contentStyle={{
                  background: "white",
                  border: "1px solid #e5e7eb",
                  borderRadius: "4px",
                  fontSize: "0.875rem",
                }}
                formatter={(value: number) => [`Mood: ${value}`, ""]}
                labelStyle={{ fontWeight: "bold" }}
              />
              <Area
                type="monotone"
                dataKey="mood"
                stroke="#1463ff"
                strokeWidth={2}
                fill="url(#moodGradient)"
              />
            </AreaChart>
          </ResponsiveContainer>
        )}
      </div>
    </article>
  );
}
