import { useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import {
  LineChart, Line, BarChart, Bar,
  XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
} from 'recharts'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'
import { daysAgo } from '../../lib/date'
import type { LogEntry } from '../../lib/types'

type AnalyticsLogEntry = Omit<LogEntry, 'habits'> & {
  habits: string[] | null
}

const DAY_NAMES = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

export async function fetchEntries(userId: string, range: number): Promise<AnalyticsLogEntry[]> {
  const { data, error } = await supabase
    .from('log_entries')
    .select('id, date, mood, habits, notes, user_id, created_at, updated_at')
    .eq('user_id', userId)
    .gte('date', daysAgo(range))
    .order('date', { ascending: true })

  if (error) throw error
  return (data ?? []).map((entry) => ({
    ...entry,
    habits: Array.isArray(entry.habits) ? entry.habits : [],
  })) as AnalyticsLogEntry[]
}

export function buildMoodTrend(entries: AnalyticsLogEntry[]): { date: string; mood: number }[] {
  return entries
    .filter((e) => e.mood != null)
    .map((e) => ({ date: e.date.slice(5), mood: e.mood as number }))
}

export function buildMoodDistribution(entries: AnalyticsLogEntry[]): { mood: string; count: number }[] {
  const counts: Record<number, number> = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 }
  for (const e of entries) {
    if (e.mood != null) {
      counts[e.mood] = (counts[e.mood] ?? 0) + 1
    }
  }
  return Object.entries(counts).map(([mood, count]) => ({ mood, count }))
}

export function buildBestDayOfWeek(entries: AnalyticsLogEntry[]): { day: string; avg: number }[] {
  const daySums: Record<number, { sum: number; count: number }> = {}
  for (const e of entries) {
    if (e.mood == null) continue
    const day = new Date(e.date).getDay()
    if (!daySums[day]) daySums[day] = { sum: 0, count: 0 }
    daySums[day].sum += e.mood
    daySums[day].count += 1
  }
  return DAY_NAMES.map((day, i) => ({
    day,
    avg: daySums[i] ? +(daySums[i].sum / daySums[i].count).toFixed(2) : 0,
  }))
}

export function buildHabitCorrelation(entries: AnalyticsLogEntry[]): { habit: string; count: number }[] {
  const highMoodEntries = entries.filter((e) => e.mood != null && e.mood >= 4)
  const freq: Record<string, number> = {}
  for (const e of highMoodEntries) {
    for (const h of e.habits ?? []) {
      freq[h] = (freq[h] ?? 0) + 1
    }
  }
  return Object.entries(freq)
    .map(([habit, count]) => ({ habit, count }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 8)
}

export function buildHabitFrequency(entries: AnalyticsLogEntry[]): { habit: string; count: number }[] {
  const freq: Record<string, number> = {}
  for (const e of entries) {
    for (const h of e.habits ?? []) {
      freq[h] = (freq[h] ?? 0) + 1
    }
  }
  return Object.entries(freq)
    .map(([habit, count]) => ({ habit, count }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 8)
}

export function buildStreakDays(entries: AnalyticsLogEntry[]): Set<string> {
  return new Set(entries.map((e) => e.date.slice(0, 10)))
}

function StreakCalendar({ loggedDays }: { loggedDays: Set<string> }) {
  const cells = useMemo(() => {
    const today = new Date()
    const out: { dateStr: string; logged: boolean }[] = []
    for (let i = 83; i >= 0; i--) {
      const d = new Date(today)
      d.setDate(today.getDate() - i)
      const dateStr = d.toISOString().slice(0, 10)
      out.push({ dateStr, logged: loggedDays.has(dateStr) })
    }
    return out
  }, [loggedDays])

  return (
    <div
      style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(12, 1fr)',
        gap: '3px',
      }}
    >
      {cells.map(({ dateStr, logged }) => (
        <div
          key={dateStr}
          title={dateStr}
          style={{
            aspectRatio: '1',
            borderRadius: '3px',
            background: logged ? 'var(--brand)' : 'var(--line)',
            opacity: logged ? 1 : 0.5,
          }}
        />
      ))}
    </div>
  )
}

function Skeleton() {
  return (
    <div className="card animate-stagger">
      {[1, 2, 3, 4, 5].map((i) => (
        <div
          key={i}
          style={{
            height: '200px',
            background: 'var(--line)',
            borderRadius: '12px',
            marginBottom: '1rem',
            animation: 'pulse 1.5s ease-in-out infinite',
          }}
        />
      ))}
    </div>
  )
}

function EmptyAnalytics({ recentlyJoined }: { recentlyJoined: boolean }) {
  return (
    <section className="card full-width placeholder-page" style={{ textAlign: 'center', padding: '3rem 1rem' }}>
      <div style={{ fontSize: '4rem', marginBottom: '1rem' }}>📊</div>
      <h2>Analytics</h2>
      {recentlyJoined ? (
        <>
          <p className="muted" style={{ maxWidth: '400px', margin: '0.5rem auto' }}>
            Welcome! Start logging your mood to see personalized charts and trends here.
            Log at least 7 entries to unlock your analytics.
          </p>
          <div style={{ marginTop: '1.5rem', fontSize: '2rem', display: 'flex', gap: '0.5rem', justifyContent: 'center' }}>
            <span>🙁</span><span>😕</span><span>😐</span><span>🙂</span><span>😄</span>
          </div>
        </>
      ) : (
        <p className="muted">No log entries found for the selected period. Start logging to see your trends here.</p>
      )}
    </section>
  )
}

export function AnalyticsPage() {
  const { user } = useAuth()
  const [range, setRange] = useState<7 | 30>(30)

  const query = useQuery({
    queryKey: ['analytics-entries', user?.id, range],
    queryFn: () => fetchEntries(user!.id, range),
    enabled: Boolean(user?.id),
  })

  if (query.isLoading) return <Skeleton />
  if (query.isError) {
    return (
      <section className="card full-width">
        <p className="muted">Failed to load analytics data. Please try again.</p>
      </section>
    )
  }

  const entries = query.data ?? []

  if (entries.length === 0) {
    return <EmptyAnalytics recentlyJoined={false} />
  }

  if (entries.length < 7) {
    return <EmptyAnalytics recentlyJoined={true} />
  }

  const moodTrend = buildMoodTrend(entries)
  const moodDist = buildMoodDistribution(entries)
  const bestDays = buildBestDayOfWeek(entries)
  const habitCorr = buildHabitCorrelation(entries)
  const habitFreq = buildHabitFrequency(entries)
  const loggedDays = buildStreakDays(entries)

  return (
    <div className="page-wrap animate-stagger" style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h1 style={{ margin: 0 }}>Analytics</h1>
        <div className="chip-row" style={{ margin: 0 }}>
          <button
            type="button"
            className={range === 7 ? 'chip active' : 'chip'}
            onClick={() => setRange(7)}
          >
            7 days
          </button>
          <button
            type="button"
            className={range === 30 ? 'chip active' : 'chip'}
            onClick={() => setRange(30)}
          >
            30 days
          </button>
        </div>
      </div>

      {/* Mood trend line chart */}
      <section className="card">
        <h2 style={{ marginTop: 0 }}>Mood Trend</h2>
        {moodTrend.length > 0 ? (
          <ResponsiveContainer width="100%" height={240}>
            <LineChart data={moodTrend}>
              <CartesianGrid strokeDasharray="3 3" stroke="var(--line)" />
              <XAxis dataKey="date" tick={{ fontSize: 11, fill: 'var(--muted)' }} />
              <YAxis domain={[1, 5]} ticks={[1, 2, 3, 4, 5]} tick={{ fontSize: 11, fill: 'var(--muted)' }} />
              <Tooltip contentStyle={{ background: 'var(--surface)', border: '1px solid var(--line)', borderRadius: '8px' }} />
              <Line type="monotone" dataKey="mood" stroke="var(--brand)" strokeWidth={2} dot={false} />
            </LineChart>
          </ResponsiveContainer>
        ) : (
          <p className="muted" style={{ padding: '2rem 0', textAlign: 'center' }}>
            No mood values recorded in this period.
          </p>
        )}
      </section>

      {/* Mood distribution bar chart */}
      <section className="card">
        <h2 style={{ marginTop: 0 }}>Mood Distribution</h2>
        <ResponsiveContainer width="100%" height={200}>
          <BarChart data={moodDist}>
            <CartesianGrid strokeDasharray="3 3" stroke="var(--line)" />
            <XAxis dataKey="mood" tick={{ fontSize: 11, fill: 'var(--muted)' }} />
            <YAxis tick={{ fontSize: 11, fill: 'var(--muted)' }} />
            <Tooltip contentStyle={{ background: 'var(--surface)', border: '1px solid var(--line)', borderRadius: '8px' }} />
            <Bar dataKey="count" fill="var(--brand)" radius={[4, 4, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </section>

      {/* Best day of week */}
      <section className="card">
        <h2 style={{ marginTop: 0 }}>Best Day of the Week</h2>
        <ResponsiveContainer width="100%" height={220}>
          <BarChart data={bestDays} layout="vertical">
            <CartesianGrid strokeDasharray="3 3" stroke="var(--line)" />
            <XAxis type="number" domain={[0, 5]} tick={{ fontSize: 11, fill: 'var(--muted)' }} />
            <YAxis type="category" dataKey="day" tick={{ fontSize: 11, fill: 'var(--muted)' }} />
            <Tooltip contentStyle={{ background: 'var(--surface)', border: '1px solid var(--line)', borderRadius: '8px' }} />
            <Bar dataKey="avg" fill="var(--accent)" radius={[0, 4, 4, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </section>

      {/* Habit correlation */}
      {habitCorr.length > 0 && (
        <section className="card">
          <h2 style={{ marginTop: 0 }}>Habits on High-Mood Days</h2>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
            {habitCorr.map((item, idx) => (
              <div key={item.habit} style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                <span style={{ fontWeight: 600, minWidth: '1.5rem', color: 'var(--muted)' }}>#{idx + 1}</span>
                <span style={{ flex: 1 }}>{item.habit}</span>
                <span className="chip active" style={{ fontSize: '0.8rem' }}>
                  {item.count}x
                </span>
              </div>
            ))}
          </div>
        </section>
      )}

      {/* Habit frequency bar chart */}
      {habitFreq.length > 0 && (
        <section className="card">
          <h2 style={{ marginTop: 0 }}>Top Habits</h2>
          <ResponsiveContainer width="100%" height={220}>
            <BarChart data={habitFreq} layout="vertical">
              <CartesianGrid strokeDasharray="3 3" stroke="var(--line)" />
              <XAxis type="number" tick={{ fontSize: 11, fill: 'var(--muted)' }} />
              <YAxis type="category" dataKey="habit" width={110} tick={{ fontSize: 11, fill: 'var(--muted)' }} />
              <Tooltip contentStyle={{ background: 'var(--surface)', border: '1px solid var(--line)', borderRadius: '8px' }} />
              <Bar dataKey="count" fill="var(--brand)" radius={[0, 4, 4, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </section>
      )}

      {/* Streak calendar */}
      <section className="card">
        <h2 style={{ marginTop: 0 }}>Logging Streak — last 12 weeks</h2>
        <StreakCalendar loggedDays={loggedDays} />
        <p className="muted" style={{ marginTop: '0.5rem', fontSize: '0.8rem' }}>
          {loggedDays.size} day{loggedDays.size !== 1 ? 's' : ''} logged in the past 12 weeks
        </p>
      </section>
    </div>
  )
}
