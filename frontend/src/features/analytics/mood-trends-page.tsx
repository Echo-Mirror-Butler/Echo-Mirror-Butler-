import { useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'
import { daysAgo } from '../../lib/date'

type LogEntry = { id: string; date: string; mood: number | null; habits: string[] | null }

const WINDOWS = [
  { label: '30 days', days: 30 },
  { label: '90 days', days: 90 },
  { label: '180 days', days: 180 },
] as const

async function fetchEntries(userId: string, days: number): Promise<LogEntry[]> {
  const { data, error } = await supabase
    .from('log_entries')
    .select('id, date, mood, habits')
    .eq('user_id', userId)
    .gte('date', daysAgo(days))
    .order('date', { ascending: true })
  if (error) throw error
  return (data ?? []) as LogEntry[]
}

function buildRollingAverage(entries: LogEntry[], windowSize: number = 7): { date: string; avg: number }[] {
  const withMood = entries.filter((e) => e.mood != null)
  if (withMood.length === 0) return []
  const result: { date: string; avg: number }[] = []
  for (let i = 0; i < withMood.length; i++) {
    const start = Math.max(0, i - windowSize + 1)
    const slice = withMood.slice(start, i + 1)
    const avg = slice.reduce((s, e) => s + (e.mood as number), 0) / slice.length
    result.push({ date: withMood[i].date.slice(5), avg: +avg.toFixed(2) })
  }
  return result
}

type HabitCorrelationTrend = { habit: string; trend: 'up' | 'down' | 'flat'; recentRate: number; olderRate: number }

function buildCorrelationTrends(entries: LogEntry[], topN: number = 5): HabitCorrelationTrend[] {
  const withMood = entries.filter((e) => e.mood != null)
  if (withMood.length < 10) return []

  const freq: Record<string, number> = {}
  for (const e of withMood) {
    for (const h of e.habits ?? []) freq[h] = (freq[h] ?? 0) + 1
  }
  const topHabits = Object.entries(freq).sort((a, b) => b[1] - a[1]).slice(0, topN).map(([h]) => h)

  const mid = Math.floor(withMood.length / 2)
  const older = withMood.slice(0, mid)
  const recent = withMood.slice(mid)

  function habitMoodRate(list: LogEntry[], habit: string): number {
    const withHabit = list.filter((e) => (e.habits ?? []).includes(habit))
    if (withHabit.length === 0) return 0
    return withHabit.filter((e) => (e.mood as number) >= 4).length / withHabit.length
  }

  return topHabits.map((habit) => {
    const olderRate = habitMoodRate(older, habit)
    const recentRate = habitMoodRate(recent, habit)
    const diff = recentRate - olderRate
    const trend: HabitCorrelationTrend['trend'] = diff > 0.05 ? 'up' : diff < -0.05 ? 'down' : 'flat'
    return { habit, trend, recentRate: +recentRate.toFixed(2), olderRate: +olderRate.toFixed(2) }
  })
}

function NotEnoughData({ days }: { days: number }) {
  return (
    <div className="card" style={{ textAlign: 'center', padding: '3rem 1rem' }}>
      <div style={{ fontSize: '3rem', marginBottom: '0.5rem' }}>📈</div>
      <h3>Not enough data yet</h3>
      <p className="muted">You need more log history to show {days}-day trend data. Keep logging your mood daily!</p>
    </div>
  )
}

export function MoodTrendsPage() {
  const { user } = useAuth()
  const [window, setWindow] = useState<90 | 180>(90)

  const query = useQuery({
    queryKey: ['mood-trends', user?.id, window],
    queryFn: () => fetchEntries(user!.id, window),
    enabled: Boolean(user?.id),
  })

  const entries = query.data ?? []
  const rollingAvg = useMemo(() => buildRollingAverage(entries), [entries])
  const correlationTrends = useMemo(() => buildCorrelationTrends(entries), [entries])
  const hasEnoughData = entries.length >= 10

  return (
    <div className="page-wrap animate-stagger" style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h1 style={{ margin: 0 }}>Mood Trends</h1>
        <div className="chip-row" style={{ margin: 0 }}>
          {WINDOWS.filter((w) => w.days >= 90).map((w) => (
            <button key={w.days} type="button" className={window === w.days ? 'chip active' : 'chip'} onClick={() => setWindow(w.days as 90 | 180)}>
              {w.label}
            </button>
          ))}
        </div>
      </div>

      {query.isLoading && <div className="card"><p className="muted">Loading\u2026</p></div>}

      {!query.isLoading && !hasEnoughData && <NotEnoughData days={window} />}

      {!query.isLoading && hasEnoughData && (
        <>
          <section className="card">
            <h2 style={{ marginTop: 0 }}>Rolling Average Mood ({window} days)</h2>
            <ResponsiveContainer width="100%" height={280}>
              <LineChart data={rollingAvg}>
                <CartesianGrid strokeDasharray="3 3" stroke="var(--line)" />
                <XAxis dataKey="date" tick={{ fontSize: 10, fill: 'var(--muted)' }} />
                <YAxis domain={[1, 5]} ticks={[1, 2, 3, 4, 5]} tick={{ fontSize: 11, fill: 'var(--muted)' }} />
                <Tooltip contentStyle={{ background: 'var(--surface)', border: '1px solid var(--line)', borderRadius: '8px' }} />
                <Line type="monotone" dataKey="avg" stroke="var(--brand)" strokeWidth={2} dot={false} name="Avg Mood" />
              </LineChart>
            </ResponsiveContainer>
          </section>

          {correlationTrends.length > 0 && (
            <section className="card">
              <h2 style={{ marginTop: 0 }}>Habit Correlation Strength Over Time</h2>
              <p className="muted" style={{ marginTop: 0, fontSize: '0.85rem' }}>
                How strongly each habit correlates with high mood (score 4-5) in recent vs. older half of your data.
              </p>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '0.6rem', marginTop: '0.75rem' }}>
                {correlationTrends.map((ct) => {
                  const trendIcon = ct.trend === 'up' ? '↑ Strengthening' : ct.trend === 'down' ? '↓ Weakening' : '→ Stable'
                  const trendColor = ct.trend === 'up' ? '#22c55e' : ct.trend === 'down' ? '#f43f5e' : 'var(--muted)'
                  return (
                    <div key={ct.habit} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0.5rem 0.75rem', borderRadius: '8px', background: 'var(--surface-soft)' }}>
                      <span style={{ fontWeight: 500 }}>{ct.habit}</span>
                      <span style={{ fontSize: '0.82rem', color: trendColor, fontWeight: 600 }}>{trendIcon}</span>
                    </div>
                  )
                })}
              </div>
            </section>
          )}
        </>
      )}
    </div>
  )
}
