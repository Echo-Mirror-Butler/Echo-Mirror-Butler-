import { useMemo, useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import {
  LineChart, Line, BarChart, Bar,
  XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
} from 'recharts'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'
import { HabitMoodHeatmap } from './components/HabitMoodHeatmap'

type LogEntry = {
  id: string
  date: string
  mood: number | null
  habits: string[] | null
}

const DAY_NAMES = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

function daysAgo(days: number): string {
  const d = new Date()
  d.setDate(d.getDate() - days)
  return d.toISOString().slice(0, 10)
}

async function fetchEntries(userId: string, range: number): Promise<LogEntry[]> {
  const { data, error } = await supabase
    .from('log_entries')
    .select('id, date, mood, habits')
    .eq('user_id', userId)
    .gte('date', daysAgo(range))
    .order('date', { ascending: true })

  if (error) throw error
  return (data ?? []) as LogEntry[]
}

function buildMoodTrend(entries: LogEntry[]): { date: string; mood: number }[] {
  return entries
    .filter((e) => e.mood != null)
    .map((e) => ({ date: e.date.slice(5), mood: e.mood as number }))
}

function buildMoodDistribution(entries: LogEntry[]): { mood: string; count: number }[] {
  const counts: Record<number, number> = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 }
  for (const e of entries) {
    if (e.mood != null) {
      counts[e.mood] = (counts[e.mood] ?? 0) + 1
    }
  }
  return Object.entries(counts).map(([mood, count]) => ({ mood, count }))
}

function buildBestDayOfWeek(entries: LogEntry[]): { day: string; avg: number }[] {
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

function buildHabitCorrelation(entries: LogEntry[]): { habit: string; count: number }[] {
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

function buildStreakDays(entries: LogEntry[]): Map<string, number> {
  const map = new Map<string, number>()
  for (const e of entries) {
    if (e.mood != null) {
      map.set(e.date.slice(0, 10), e.mood)
    } else {
      map.set(e.date.slice(0, 10), 0)
    }
  }
  return map
}

function StreakCalendar({ daysMap, weekCount: propWeekCount }: { daysMap: Map<string, number>; weekCount?: number }) {
  const navigate = useNavigate()
  const [width, setWidth] = useState(typeof window !== 'undefined' ? window.innerWidth : 1200)

  useEffect(() => {
    const onResize = () => setWidth(window.innerWidth)
    window.addEventListener('resize', onResize)
    return () => window.removeEventListener('resize', onResize)
  }, [])

  const isMobile = width < 480
  const weekCount = isMobile ? 8 : (propWeekCount ?? 12)

  const today = new Date()
  const dayOfWeek = today.getDay()
  const offsetToMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1

  const totalDays = weekCount * 7

  const cells = useMemo(() => {
    const out: { dateStr: string; mood: number; logged: boolean }[] = []
    for (let i = totalDays - 1; i >= 0; i--) {
      const d = new Date(today)
      d.setDate(today.getDate() - i - offsetToMonday)
      const dateStr = d.toISOString().slice(0, 10)
      const mood = daysMap.get(dateStr) ?? 0
      out.push({ dateStr, mood, logged: mood > 0 })
    }
    return out
  }, [daysMap, totalDays, offsetToMonday])

  const dayHeaders = ['M', 'T', 'W', 'T', 'F', 'S', 'S']

  function getMoodColor(mood: number, logged: boolean): string {
    if (!logged) return 'var(--line)'
    if (mood <= 2) return 'var(--pastel-blue, #a5b4fc)'
    if (mood === 3) return 'var(--brand)'
    return 'var(--brand)'
  }

  function getMoodOpacity(mood: number, logged: boolean): number {
    if (!logged) return 0.3
    if (mood <= 2) return 0.55
    if (mood === 3) return 0.75
    return 1
  }

  return (
    <div>
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: `repeat(7, 1fr)`,
          gap: '3px',
          marginBottom: '4px',
        }}
      >
        {dayHeaders.map((day) => (
          <div
            key={day}
            style={{
              textAlign: 'center',
              fontSize: '0.7rem',
              fontWeight: 600,
              color: 'var(--muted)',
              textTransform: 'uppercase',
            }}
          >
            {day}
          </div>
        ))}
      </div>
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: `repeat(7, 1fr)`,
          gap: '3px',
        }}
      >
        {cells.map(({ dateStr, mood, logged }) => {
          const formattedDate = new Date(dateStr + 'T00:00:00').toLocaleDateString(undefined, {
            weekday: 'long', year: 'numeric', month: 'long', day: 'numeric',
          })

          if (logged) {
            return (
              <div
                key={dateStr}
                role="button"
                tabIndex={0}
                aria-label={`View log for ${formattedDate}`}
                title={dateStr}
                onClick={() => navigate(`/logs?date=${dateStr}`)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault()
                    navigate(`/logs?date=${dateStr}`)
                  }
                }}
                style={{
                  aspectRatio: '1',
                  borderRadius: '3px',
                  background: getMoodColor(mood, true),
                  opacity: getMoodOpacity(mood, true),
                  cursor: 'pointer',
                  transition: 'opacity 0.15s ease',
                }}
              />
            )
          }

          return (
            <div
              key={dateStr}
              aria-label={`${formattedDate} — no log`}
              title={dateStr}
              style={{
                aspectRatio: '1',
                borderRadius: '3px',
                background: 'var(--line)',
                opacity: 0.3,
              }}
            />
          )
        })}
      </div>
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
  const daysMap = buildStreakDays(entries)

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

      {/* Habit × Mood heatmap (requires ≥14 entries) */}
      {entries.length >= 14 && (
        <section className="card">
          <h2 style={{ marginTop: 0 }}>Habit × Mood Heatmap</h2>
          <p className="muted" style={{ marginTop: 0, marginBottom: '1rem', fontSize: '0.85rem' }}>
            How often each habit was logged on days with a given mood score.
          </p>
          <HabitMoodHeatmap entries={entries} />
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
        <StreakCalendar daysMap={daysMap} />
        <p className="muted" style={{ marginTop: '0.5rem', fontSize: '0.8rem' }}>
          {daysMap.size} day{daysMap.size !== 1 ? 's' : ''} logged
        </p>
      </section>
    </div>
  )
}
