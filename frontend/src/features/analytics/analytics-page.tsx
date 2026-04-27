import { useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import {
  AreaChart,
  Area,
  BarChart,
  Bar,
  LineChart,
  Line,
  PieChart,
  Pie,
  Cell,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'
import { toDateInputValue } from '../../lib/date'
import type { LogEntry } from '../../lib/types'

// ── Constants ──────────────────────────────────────────────────────────────

type Range = '7' | '30' | '90' | '365' | 'all'

const RANGE_OPTIONS: { label: string; value: Range }[] = [
  { label: 'Last 7 days', value: '7' },
  { label: 'Last 30 days', value: '30' },
  { label: 'Last 90 days', value: '90' },
  { label: 'Last 365 days', value: '365' },
  { label: 'All time', value: 'all' },
]

// Mood 1–5 → green shades; no log → grey
const MOOD_COLORS: Record<number, string> = {
  1: '#bbf7d0',
  2: '#86efac',
  3: '#4ade80',
  4: '#22c55e',
  5: '#16a34a',
}
const NO_LOG_COLOR = '#e5e7eb'

const MOOD_LABELS: Record<number, string> = {
  1: '😞 Very Low',
  2: '😕 Low',
  3: '😐 Neutral',
  4: '🙂 Good',
  5: '😄 Great',
}

const PIE_COLORS = ['#bbf7d0', '#86efac', '#4ade80', '#22c55e', '#16a34a']

// ── Data fetching ─────────────────────────────────────────────────────────

async function fetchAnalyticsLogs(userId: string, days: number | null): Promise<LogEntry[]> {
  let query = supabase
    .from('log_entries')
    .select('*')
    .eq('user_id', userId)
    .order('date', { ascending: true })

  if (days !== null) {
    const since = new Date()
    since.setDate(since.getDate() - days)
    query = query.gte('date', since.toISOString())
  }

  const { data, error } = await query
  if (error) throw error
  return ((data ?? []) as LogEntry[]).map((e) => ({
    ...e,
    habits: Array.isArray(e.habits) ? e.habits : [],
  }))
}

// ── Analytics computations ────────────────────────────────────────────────

function dateKey(isoString: string): string {
  return isoString.slice(0, 10)
}

function computeStats(logs: LogEntry[]) {
  const uniqueDates = [...new Set(logs.map((l) => dateKey(l.date)))].sort()
  const dateSet = new Set(uniqueDates)

  // Current streak (consecutive days ending today or yesterday)
  let currentStreak = 0
  const cursor = new Date()
  while (dateSet.has(toDateInputValue(cursor))) {
    currentStreak++
    cursor.setDate(cursor.getDate() - 1)
  }

  // Longest streak
  let longestStreak = uniqueDates.length > 0 ? 1 : 0
  let run = uniqueDates.length > 0 ? 1 : 0
  for (let i = 1; i < uniqueDates.length; i++) {
    const prev = new Date(uniqueDates[i - 1])
    const curr = new Date(uniqueDates[i])
    const diffDays = Math.round((curr.getTime() - prev.getTime()) / 86_400_000)
    if (diffDays === 1) {
      run++
      if (run > longestStreak) longestStreak = run
    } else {
      run = 1
    }
  }

  // Most logged habit
  const habitCounts: Record<string, number> = {}
  for (const log of logs) {
    for (const habit of log.habits) {
      habitCounts[habit] = (habitCounts[habit] ?? 0) + 1
    }
  }
  const mostLoggedHabit =
    Object.entries(habitCounts).sort((a, b) => b[1] - a[1])[0]?.[0] ?? '—'

  return { currentStreak, longestStreak, totalLogDays: uniqueDates.length, mostLoggedHabit }
}

function buildMoodOverTime(logs: LogEntry[]) {
  return logs
    .filter((l) => l.mood !== null)
    .map((l) => ({ date: dateKey(l.date), mood: l.mood as number }))
}

function buildHabitFrequency(logs: LogEntry[]) {
  const counts: Record<string, number> = {}
  for (const log of logs) {
    for (const habit of log.habits) {
      counts[habit] = (counts[habit] ?? 0) + 1
    }
  }
  return Object.entries(counts)
    .map(([habit, count]) => ({ habit, count }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 15)
}

function buildMoodDistribution(logs: LogEntry[]) {
  const counts: Record<number, number> = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 }
  for (const log of logs) {
    if (log.mood !== null && log.mood >= 1 && log.mood <= 5) {
      counts[log.mood]++
    }
  }
  return [1, 2, 3, 4, 5]
    .filter((m) => counts[m] > 0)
    .map((m) => ({ name: MOOD_LABELS[m], value: counts[m], mood: m }))
}

function buildLogConsistency(logs: LogEntry[]) {
  let total = 0
  return logs.map((l) => ({ date: dateKey(l.date), total: ++total }))
}

// ── Streak Calendar ───────────────────────────────────────────────────────

function buildCalendarGrid(logs: LogEntry[], days: number | null) {
  const moodByDate: Record<string, number> = {}
  for (const log of logs) {
    if (log.mood !== null) moodByDate[dateKey(log.date)] = log.mood
    else if (!moodByDate[dateKey(log.date)]) moodByDate[dateKey(log.date)] = 0
  }

  const totalDays = days ?? 365
  const end = new Date()
  const start = new Date()
  start.setDate(end.getDate() - totalDays + 1)

  // Align start to Monday
  const dayOfWeek = start.getDay()
  const offset = dayOfWeek === 0 ? 6 : dayOfWeek - 1
  start.setDate(start.getDate() - offset)

  const cells: { date: string; mood: number | null }[] = []
  const cur = new Date(start)
  while (cur <= end) {
    const key = toDateInputValue(cur)
    cells.push({ date: key, mood: moodByDate[key] !== undefined ? moodByDate[key] : null })
    cur.setDate(cur.getDate() + 1)
  }

  // Group into weeks (each week = 7 days Mon–Sun)
  const weeks: { date: string; mood: number | null }[][] = []
  for (let i = 0; i < cells.length; i += 7) {
    weeks.push(cells.slice(i, i + 7))
  }
  return weeks
}

// ── Tooltip formatters ────────────────────────────────────────────────────

function MoodTooltip({ active, payload, label }: { active?: boolean; payload?: { value: number }[]; label?: string }) {
  if (!active || !payload?.length) return null
  return (
    <div className="analytics-tooltip">
      <p className="analytics-tooltip-date">{label}</p>
      <p>Mood: <strong>{payload[0].value} / 5</strong></p>
    </div>
  )
}

function HabitTooltip({ active, payload, label }: { active?: boolean; payload?: { value: number }[]; label?: string }) {
  if (!active || !payload?.length) return null
  return (
    <div className="analytics-tooltip">
      <p className="analytics-tooltip-date">{label}</p>
      <p>Days logged: <strong>{payload[0].value}</strong></p>
    </div>
  )
}

function ConsistencyTooltip({ active, payload, label }: { active?: boolean; payload?: { value: number }[]; label?: string }) {
  if (!active || !payload?.length) return null
  return (
    <div className="analytics-tooltip">
      <p className="analytics-tooltip-date">{label}</p>
      <p>Total logs: <strong>{payload[0].value}</strong></p>
    </div>
  )
}

// ── Main page ─────────────────────────────────────────────────────────────

export function AnalyticsPage() {
  const { user } = useAuth()
  const [range, setRange] = useState<Range>('30')

  const days = range === 'all' ? null : parseInt(range, 10)

  const logsQuery = useQuery({
    queryKey: ['analytics-logs', user?.id, range],
    queryFn: () => fetchAnalyticsLogs(user!.id, days),
    enabled: Boolean(user?.id),
  })

  const logs = logsQuery.data ?? []
  const isEmpty = !logsQuery.isLoading && logs.length < 3

  const stats = useMemo(() => computeStats(logs), [logs])
  const moodOverTime = useMemo(() => buildMoodOverTime(logs), [logs])
  const habitFrequency = useMemo(() => buildHabitFrequency(logs), [logs])
  const moodDistribution = useMemo(() => buildMoodDistribution(logs), [logs])
  const logConsistency = useMemo(() => buildLogConsistency(logs), [logs])
  const calendarWeeks = useMemo(() => buildCalendarGrid(logs, days), [logs, days])

  if (!user) return null

  return (
    <section className="analytics-page">
      {/* ── Header + range filter ── */}
      <div className="analytics-header">
        <div>
          <h2>Analytics</h2>
          <p className="muted">Visualise your mood trends, habits, and consistency.</p>
        </div>
        <div className="analytics-range-tabs" role="group" aria-label="Date range">
          {RANGE_OPTIONS.map((opt) => (
            <button
              key={opt.value}
              type="button"
              className={`analytics-range-btn${range === opt.value ? ' active' : ''}`}
              onClick={() => setRange(opt.value)}
            >
              {opt.label}
            </button>
          ))}
        </div>
      </div>

      {/* ── Loading ── */}
      {logsQuery.isLoading ? (
        <div className="analytics-loading">
          <div className="skeleton-line" />
          <div className="skeleton-line" />
          <div className="skeleton-line" />
        </div>
      ) : isEmpty ? (
        /* ── Empty state ── */
        <div className="analytics-empty">
          <span className="analytics-empty-icon">📊</span>
          <h3>Not enough data yet</h3>
          <p className="muted">Log at least 3 entries to unlock your analytics dashboard.</p>
          <a href="/logs/new" className="analytics-cta-link">Start logging →</a>
        </div>
      ) : (
        <>
          {/* ── Stats summary row ── */}
          <div className="analytics-stats-row">
            <div className="analytics-stat-card">
              <span className="analytics-stat-icon">🔥</span>
              <p className="analytics-stat-value">{stats.currentStreak}</p>
              <p className="analytics-stat-label">Current streak</p>
            </div>
            <div className="analytics-stat-card">
              <span className="analytics-stat-icon">🏆</span>
              <p className="analytics-stat-value">{stats.longestStreak}</p>
              <p className="analytics-stat-label">Longest streak</p>
            </div>
            <div className="analytics-stat-card">
              <span className="analytics-stat-icon">📅</span>
              <p className="analytics-stat-value">{stats.totalLogDays}</p>
              <p className="analytics-stat-label">Total log days</p>
            </div>
            <div className="analytics-stat-card">
              <span className="analytics-stat-icon">⭐</span>
              <p className="analytics-stat-value analytics-stat-value--sm">{stats.mostLoggedHabit}</p>
              <p className="analytics-stat-label">Top habit</p>
            </div>
          </div>

          {/* ── Charts grid ── */}
          <div className="analytics-charts-grid">

            {/* 1. Mood over time */}
            <div className="card analytics-chart-card full-width">
              <h3>Mood over time</h3>
              <div className="analytics-chart-scroll">
                <div style={{ minWidth: Math.max(500, moodOverTime.length * 18) }}>
                  <ResponsiveContainer width="100%" height={220}>
                    <LineChart data={moodOverTime} margin={{ top: 8, right: 16, left: 0, bottom: 0 }}>
                      <CartesianGrid strokeDasharray="3 3" stroke="var(--line)" />
                      <XAxis dataKey="date" tick={{ fontSize: 11 }} tickLine={false} interval="preserveStartEnd" />
                      <YAxis domain={[1, 5]} ticks={[1, 2, 3, 4, 5]} tick={{ fontSize: 11 }} tickLine={false} />
                      <Tooltip content={<MoodTooltip />} />
                      <Line
                        type="monotone"
                        dataKey="mood"
                        stroke="var(--brand)"
                        strokeWidth={2}
                        dot={{ r: 3, fill: 'var(--brand)' }}
                        activeDot={{ r: 5 }}
                      />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              </div>
            </div>

            {/* 2. Habit frequency */}
            <div className="card analytics-chart-card">
              <h3>Habit frequency</h3>
              <div className="analytics-chart-scroll">
                <div style={{ minWidth: Math.max(360, habitFrequency.length * 48) }}>
                  <ResponsiveContainer width="100%" height={220}>
                    <BarChart data={habitFrequency} margin={{ top: 8, right: 16, left: 0, bottom: 40 }}>
                      <CartesianGrid strokeDasharray="3 3" stroke="var(--line)" vertical={false} />
                      <XAxis
                        dataKey="habit"
                        tick={{ fontSize: 11 }}
                        tickLine={false}
                        angle={-35}
                        textAnchor="end"
                        interval={0}
                      />
                      <YAxis allowDecimals={false} tick={{ fontSize: 11 }} tickLine={false} />
                      <Tooltip content={<HabitTooltip />} />
                      <Bar dataKey="count" fill="var(--brand)" radius={[4, 4, 0, 0]} />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              </div>
            </div>

            {/* 3. Mood distribution */}
            <div className="card analytics-chart-card">
              <h3>Mood distribution</h3>
              <ResponsiveContainer width="100%" height={220}>
                <PieChart>
                  <Pie
                    data={moodDistribution}
                    dataKey="value"
                    nameKey="name"
                    cx="50%"
                    cy="50%"
                    outerRadius={80}
                    label={({ name, percent }) =>
                      `${name} (${Math.round((percent ?? 0) * 100)}%)`
                    }
                    labelLine={false}
                  >
                    {moodDistribution.map((entry) => (
                      <Cell key={entry.mood} fill={PIE_COLORS[entry.mood - 1]} />
                    ))}
                  </Pie>
                  <Tooltip formatter={(value) => [`${value} days`, 'Count']} />
                  <Legend iconSize={10} wrapperStyle={{ fontSize: 11 }} />
                </PieChart>
              </ResponsiveContainer>
            </div>

            {/* 4. Log consistency */}
            <div className="card analytics-chart-card full-width">
              <h3>Log consistency (cumulative)</h3>
              <div className="analytics-chart-scroll">
                <div style={{ minWidth: Math.max(500, logConsistency.length * 18) }}>
                  <ResponsiveContainer width="100%" height={200}>
                    <AreaChart data={logConsistency} margin={{ top: 8, right: 16, left: 0, bottom: 0 }}>
                      <defs>
                        <linearGradient id="consistencyGrad" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="var(--brand)" stopOpacity={0.25} />
                          <stop offset="95%" stopColor="var(--brand)" stopOpacity={0} />
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" stroke="var(--line)" />
                      <XAxis dataKey="date" tick={{ fontSize: 11 }} tickLine={false} interval="preserveStartEnd" />
                      <YAxis allowDecimals={false} tick={{ fontSize: 11 }} tickLine={false} />
                      <Tooltip content={<ConsistencyTooltip />} />
                      <Area
                        type="monotone"
                        dataKey="total"
                        stroke="var(--brand)"
                        strokeWidth={2}
                        fill="url(#consistencyGrad)"
                      />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
              </div>
            </div>

            {/* 5. Streak calendar */}
            <div className="card analytics-chart-card full-width">
              <h3>Streak calendar</h3>
              <div className="analytics-calendar-legend">
                <span className="muted" style={{ fontSize: '0.75rem' }}>Less</span>
                <span className="calendar-cell" style={{ background: NO_LOG_COLOR }} title="No log" />
                {[1, 2, 3, 4, 5].map((m) => (
                  <span
                    key={m}
                    className="calendar-cell"
                    style={{ background: MOOD_COLORS[m] }}
                    title={MOOD_LABELS[m]}
                  />
                ))}
                <span className="muted" style={{ fontSize: '0.75rem' }}>More</span>
              </div>
              <div className="analytics-chart-scroll">
                <div className="calendar-grid">
                  {/* Day labels column */}
                  <div className="calendar-day-labels">
                    {['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((d) => (
                      <span key={d} className="calendar-day-label">{d}</span>
                    ))}
                  </div>

                  {/* Week columns */}
                  {calendarWeeks.map((week, wi) => (
                    <div key={wi} className="calendar-week">
                      {week.map((cell, di) => (
                        <div
                          key={di}
                          className="calendar-cell"
                          style={{
                            background:
                              cell.mood === null
                                ? NO_LOG_COLOR
                                : cell.mood === 0
                                  ? '#d1fae5'
                                  : MOOD_COLORS[cell.mood],
                          }}
                          title={
                            cell.mood === null
                              ? `${cell.date}: no log`
                              : `${cell.date}: mood ${cell.mood}`
                          }
                          aria-label={
                            cell.mood === null
                              ? `${cell.date}: no log`
                              : `${cell.date}: mood ${cell.mood}`
                          }
                        />
                      ))}
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </>
      )}
    </section>
  )
}
