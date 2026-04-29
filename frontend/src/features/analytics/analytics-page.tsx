/**
 * Analytics Page  (#259)
 *
 * Sections:
 * 1. Mood trend line chart (daily mood score over 30 days)
 * 2. Habit frequency bar chart (top 8 habits over 30 days)
 * 3. Streak calendar (12-week grid)
 */
import { useMemo } from 'react'
import { useQuery } from '@tanstack/react-query'
import {
  LineChart, Line, BarChart, Bar,
  XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
} from 'recharts'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'

// ── Types ─────────────────────────────────────────────────────────────────────

type LogEntry = {
  id: string
  date: string
  mood: number | null
  habits: string[] | null
}

// ── Data helpers ──────────────────────────────────────────────────────────────

function thirtyDaysAgo(): string {
  const d = new Date()
  d.setDate(d.getDate() - 30)
  return d.toISOString().slice(0, 10)
}

async function fetchEntries(userId: string): Promise<LogEntry[]> {
  const { data, error } = await supabase
    .from('log_entries')
    .select('id, date, mood, habits')
    .eq('user_id', userId)
    .gte('date', thirtyDaysAgo())
    .order('date', { ascending: true })

  if (error) throw error
  return (data ?? []) as LogEntry[]
}

function buildMoodTrend(entries: LogEntry[]): { date: string; mood: number }[] {
  return entries
    .filter((e) => e.mood != null)
    .map((e) => ({ date: e.date.slice(5), mood: e.mood as number }))
}

function buildHabitFrequency(entries: LogEntry[]): { habit: string; count: number }[] {
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

function buildStreakDays(entries: LogEntry[]): Set<string> {
  return new Set(entries.map((e) => e.date.slice(0, 10)))
}

// ── Sub-components ────────────────────────────────────────────────────────────

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
      {[1, 2, 3].map((i) => (
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

// ── Page ──────────────────────────────────────────────────────────────────────

export function AnalyticsPage() {
  const { user } = useAuth()

  const query = useQuery({
    queryKey: ['analytics-entries', user?.id],
    queryFn: () => fetchEntries(user!.id),
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
    return (
      <section className="card full-width placeholder-page">
        <h2>Analytics</h2>
        <p className="muted">No log entries found for the past 30 days. Start logging to see your trends here.</p>
      </section>
    )
  }

  const moodTrend = buildMoodTrend(entries)
  const habitFreq = buildHabitFrequency(entries)
  const loggedDays = buildStreakDays(entries)

  return (
    <div className="page-wrap animate-stagger" style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
      <h1>Analytics</h1>

      {/* Mood trend */}
      <section className="card">
        <h2 style={{ marginTop: 0 }}>Mood Trend — last 30 days</h2>
        <ResponsiveContainer width="100%" height={220}>
          <LineChart data={moodTrend}>
            <CartesianGrid strokeDasharray="3 3" stroke="var(--line)" />
            <XAxis dataKey="date" tick={{ fontSize: 11, fill: 'var(--muted)' }} />
            <YAxis domain={[1, 5]} ticks={[1, 2, 3, 4, 5]} tick={{ fontSize: 11, fill: 'var(--muted)' }} />
            <Tooltip contentStyle={{ background: 'var(--surface)', border: '1px solid var(--line)', borderRadius: '8px' }} />
            <Line type="monotone" dataKey="mood" stroke="var(--brand)" strokeWidth={2} dot={false} />
          </LineChart>
        </ResponsiveContainer>
      </section>

      {/* Habit frequency */}
      {habitFreq.length > 0 && (
        <section className="card">
          <h2 style={{ marginTop: 0 }}>Top Habits — last 30 days</h2>
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
