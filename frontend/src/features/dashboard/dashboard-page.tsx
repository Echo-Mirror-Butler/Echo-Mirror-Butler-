import { useMemo } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import {
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'
import type { Insight, LogEntry } from '../../lib/types'
import { formatDate, formatDateTime, moodToEmoji, toDateInputValue } from '../../lib/date'

type DashboardData = {
  averageMood: number | null
  currentStreak: number
  latestInsight: Insight | null
  moodTrend: Array<{ date: string; label: string; mood: number | null }>
  recentLogs: LogEntry[]
  totalLogs: number
  walletBalance: number
}

type DashboardLogRow = Pick<LogEntry, 'id' | 'date' | 'mood' | 'habits'>

function isMissingRelationError(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'message' in error &&
    typeof (error as { message: string }).message === 'string' &&
    (error as { message: string }).message.toLowerCase().includes('relation')
  )
}

function isMissingColumnError(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'message' in error &&
    typeof (error as { message: string }).message === 'string' &&
    (error as { message: string }).message.toLowerCase().includes('column')
  )
}

function getGreeting(date = new Date()): string {
  const hour = date.getHours()
  if (hour < 12) {
    return 'Good morning'
  }
  if (hour < 18) {
    return 'Good afternoon'
  }
  return 'Good evening'
}

function getDisplayName(user: ReturnType<typeof useAuth>['user']): string {
  if (!user) {
    return 'there'
  }

  const metadataName = String(user.user_metadata?.full_name ?? user.user_metadata?.name ?? '').trim()
  if (metadataName) {
    return metadataName.split(' ')[0]
  }

  const emailName = user.email?.split('@')[0]?.trim()
  return emailName || 'there'
}

function formatChartLabel(dateValue: string): string {
  return new Intl.DateTimeFormat(undefined, { weekday: 'short' }).format(new Date(dateValue))
}

function normalizeLogRow(entry: DashboardLogRow): LogEntry {
  return {
    ...entry,
    user_id: '',
    notes: null,
    created_at: entry.date,
    updated_at: entry.date,
    habits: Array.isArray(entry.habits) ? entry.habits : [],
  }
}

function buildMoodTrend(entries: DashboardLogRow[]): Array<{ date: string; label: string; mood: number | null }> {
  const byDay = new Map<string, number[]>()

  for (const entry of entries) {
    if (typeof entry.mood !== 'number') {
      continue
    }

    const dateKey = entry.date.slice(0, 10)
    const bucket = byDay.get(dateKey) ?? []
    bucket.push(entry.mood)
    byDay.set(dateKey, bucket)
  }

  return Array.from({ length: 7 }).map((_, index) => {
    const date = new Date()
    date.setHours(0, 0, 0, 0)
    date.setDate(date.getDate() - (6 - index))
    const dateKey = date.toISOString().slice(0, 10)
    const moods = byDay.get(dateKey) ?? []
    const mood =
      moods.length > 0 ? moods.reduce((sum, value) => sum + value, 0) / moods.length : null

    return {
      date: dateKey,
      label: formatChartLabel(dateKey),
      mood: mood ? Number(mood.toFixed(1)) : null,
    }
  })
}

function calculateAverageMood(entries: DashboardLogRow[]): number | null {
  const moods = entries.map((entry) => entry.mood).filter((value): value is number => typeof value === 'number')
  if (!moods.length) {
    return null
  }

  const average = moods.reduce((sum, value) => sum + value, 0) / moods.length
  return Number(average.toFixed(1))
}

function calculateStreak(dates: string[]): number {
  const uniqueDays = Array.from(new Set(dates.map((value) => value.slice(0, 10))))
  if (!uniqueDays.length) {
    return 0
  }

  let streak = 1

  for (let index = 1; index < uniqueDays.length; index += 1) {
    const previous = new Date(`${uniqueDays[index - 1]}T00:00:00.000Z`)
    const current = new Date(`${uniqueDays[index]}T00:00:00.000Z`)
    const deltaDays = Math.round((previous.getTime() - current.getTime()) / 86_400_000)

    if (deltaDays === 0) {
      continue
    }

    if (deltaDays !== 1) {
      break
    }

    streak += 1
  }

  return streak
}

async function findTodayLogId(userId: string, dateValue: string): Promise<string | null> {
  const startOfDay = new Date(`${dateValue}T00:00:00.000Z`).toISOString()
  const endOfDay = new Date(`${dateValue}T23:59:59.999Z`).toISOString()

  const { data, error } = await supabase
    .from('log_entries')
    .select('id')
    .eq('user_id', userId)
    .gte('date', startOfDay)
    .lte('date', endOfDay)
    .maybeSingle()

  if (error) {
    throw error
  }

  return (data?.id as string | undefined) ?? null
}

async function fetchWalletBalance(userId: string): Promise<number> {
  const { data, error } = await supabase
    .from('user_wallets')
    .select('balance')
    .eq('user_id', userId)
    .maybeSingle()

  if (error && !isMissingColumnError(error)) {
    throw error
  }

  if (data && typeof data.balance === 'number') {
    return data.balance
  }

  const [{ data: sentRows, error: sentError }, { data: receivedRows, error: receivedError }] =
    await Promise.all([
      supabase
        .from('gift_transactions')
        .select('echo_amount')
        .eq('sender_user_id', userId)
        .eq('status', 'completed'),
      supabase
        .from('gift_transactions')
        .select('echo_amount')
        .eq('recipient_user_id', userId)
        .eq('status', 'completed'),
    ])

  if (sentError) {
    throw sentError
  }

  if (receivedError) {
    throw receivedError
  }

  const sentTotal = (sentRows ?? []).reduce((sum, row) => sum + Number(row.echo_amount ?? 0), 0)
  const receivedTotal = (receivedRows ?? []).reduce(
    (sum, row) => sum + Number(row.echo_amount ?? 0),
    0,
  )

  return Math.max(0, receivedTotal - sentTotal)
}

async function fetchLatestInsight(userId: string): Promise<Insight | null> {
  const { data, error } = await supabase
    .from('ai_insights')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle()

  if (error) {
    if (isMissingRelationError(error)) {
      return null
    }
    throw error
  }

  if (!data) {
    return null
  }

  return {
    ...(data as Insight),
    suggestions: Array.isArray(data.suggestions) ? data.suggestions.map(String) : [],
  }
}

async function fetchDashboardData(userId: string): Promise<DashboardData> {
  const thirtyDaysAgo = new Date()
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)
  const thirtyDaysAgoIso = thirtyDaysAgo.toISOString()

  const [recentLogsResult, latestLogsResult, streakResult, totalCountResult, latestInsight, walletBalance] =
    await Promise.all([
      supabase
        .from('log_entries')
        .select('id,date,mood,habits')
        .eq('user_id', userId)
        .gte('date', thirtyDaysAgoIso)
        .order('date', { ascending: false }),
      supabase
        .from('log_entries')
        .select('id,date,mood,habits')
        .eq('user_id', userId)
        .order('date', { ascending: false })
        .limit(5),
      supabase.from('log_entries').select('date').eq('user_id', userId).order('date', { ascending: false }),
      supabase.from('log_entries').select('id', { count: 'exact', head: true }).eq('user_id', userId),
      fetchLatestInsight(userId),
      fetchWalletBalance(userId),
    ])

  if (recentLogsResult.error) {
    throw recentLogsResult.error
  }

  if (latestLogsResult.error) {
    throw latestLogsResult.error
  }

  if (streakResult.error) {
    throw streakResult.error
  }

  if (totalCountResult.error) {
    throw totalCountResult.error
  }

  const recentMoodRows = (recentLogsResult.data ?? []) as DashboardLogRow[]
  const recentLogs = ((latestLogsResult.data ?? []) as DashboardLogRow[]).map(normalizeLogRow)
  const streakDates = ((streakResult.data ?? []) as Array<{ date: string }>).map((entry) => entry.date)

  return {
    averageMood: calculateAverageMood(recentMoodRows),
    currentStreak: calculateStreak(streakDates),
    latestInsight,
    moodTrend: buildMoodTrend(recentMoodRows),
    recentLogs,
    totalLogs: totalCountResult.count ?? 0,
    walletBalance,
  }
}

function DashboardSkeleton() {
  return (
    <section className="dashboard-page">
      <div className="dashboard-hero dashboard-skeleton-card">
        <div className="skeleton-line large" />
        <div className="skeleton-line" />
      </div>

      <div className="dashboard-stat-grid">
        {Array.from({ length: 4 }).map((_, index) => (
          <article key={index} className="card dashboard-skeleton-card">
            <div className="skeleton-line" />
            <div className="skeleton-line large" />
          </article>
        ))}
      </div>

      <article className="card dashboard-chart-card dashboard-skeleton-card">
        <div className="skeleton-line" />
        <div className="dashboard-chart-skeleton" />
      </article>

      <div className="dashboard-lower-grid">
        <article className="card dashboard-skeleton-card">
          <div className="skeleton-line" />
          <div className="skeleton-line" />
          <div className="skeleton-line" />
        </article>
        <article className="card dashboard-skeleton-card">
          <div className="skeleton-line" />
          <div className="skeleton-line" />
          <div className="skeleton-line" />
        </article>
      </div>
    </section>
  )
}

function StatCard({
  icon,
  label,
  value,
  hint,
}: {
  icon: string
  label: string
  value: string
  hint: string
}) {
  return (
    <article className="card dashboard-stat-card">
      <div className="dashboard-stat-label">
        <span className="dashboard-stat-icon" aria-hidden="true">
          {icon}
        </span>
        <span>{label}</span>
      </div>
      <strong className="dashboard-stat-value">{value}</strong>
      <p className="muted dashboard-stat-hint">{hint}</p>
    </article>
  )
}

export function DashboardPage() {
  const navigate = useNavigate()
  const { user } = useAuth()

  const dashboardQuery = useQuery({
    queryKey: ['dashboard', user?.id],
    queryFn: () => fetchDashboardData(user!.id),
    enabled: Boolean(user?.id),
    staleTime: 60_000,
  })

  const displayName = useMemo(() => getDisplayName(user), [user])
  const greeting = useMemo(() => getGreeting(), [])

  if (!user) {
    return null
  }

  if (dashboardQuery.isLoading) {
    return <DashboardSkeleton />
  }

  if (dashboardQuery.isError) {
    return (
      <section className="card full-width">
        <h2>Dashboard</h2>
        <p className="error-text">We couldn&apos;t load your dashboard right now.</p>
        <button type="button" onClick={() => void dashboardQuery.refetch()}>
          Try again
        </button>
      </section>
    )
  }

  const data = dashboardQuery.data

  if (!data) {
    return null
  }

  const hasLogs = data.totalLogs > 0
  const firstTwoSuggestions = data.latestInsight?.suggestions.slice(0, 2) ?? []

  return (
    <section className="dashboard-page">
      <div className="dashboard-hero">
        <div>
          <p className="dashboard-eyebrow">{greeting}</p>
          <h1>{displayName}</h1>
          <p className="muted dashboard-hero-copy">
            Your mood patterns, latest AI signal, and today&apos;s journaling snapshot all in one place.
          </p>
        </div>

        <button
          type="button"
          className="dashboard-cta"
          onClick={async () => {
            const today = toDateInputValue(new Date())
            const existingId = await findTodayLogId(user.id, today)
            if (existingId) {
              navigate(`/logs/${existingId}/edit`)
              return
            }
            navigate(`/logs/new?date=${today}`)
          }}
        >
          Log Today
        </button>
      </div>

      <div className="dashboard-stat-grid">
        <StatCard
          icon="🔥"
          label="Mood streak"
          value={`${data.currentStreak} day${data.currentStreak === 1 ? '' : 's'}`}
          hint={hasLogs ? 'Consecutive days with at least one entry.' : 'Start logging to build your streak.'}
        />
        <StatCard
          icon="⭐"
          label="Avg mood"
          value={data.averageMood ? `${data.averageMood}/5` : 'No data'}
          hint="Based on the last 30 days."
        />
        <StatCard
          icon="📝"
          label="Total logs"
          value={String(data.totalLogs)}
          hint={hasLogs ? 'Your full journaling history so far.' : 'Your first entry will appear here.'}
        />
        <StatCard
          icon="💎"
          label="ECHO balance"
          value={`${data.walletBalance.toFixed(0)} ECHO`}
          hint="Current wallet balance."
        />
      </div>

      <article className="card dashboard-chart-card">
        <div className="card-header">
          <div>
            <h2>7-day mood trend</h2>
            <p className="muted dashboard-section-copy">Average mood per day from your recent check-ins.</p>
          </div>
        </div>

        {hasLogs ? (
          <div className="dashboard-chart-wrap">
            <ResponsiveContainer width="100%" height={260}>
              <LineChart data={data.moodTrend} margin={{ left: -20, right: 10, top: 12, bottom: 0 }}>
                <CartesianGrid strokeDasharray="4 4" stroke="var(--line)" vertical={false} />
                <XAxis dataKey="label" tick={{ fill: 'var(--muted)', fontSize: 12 }} axisLine={false} tickLine={false} />
                <YAxis
                  domain={[1, 5]}
                  ticks={[1, 2, 3, 4, 5]}
                  tick={{ fill: 'var(--muted)', fontSize: 12 }}
                  axisLine={false}
                  tickLine={false}
                />
                <Tooltip
                  formatter={(value: number | null) => (value ? `${value}/5` : 'No entry')}
                  labelFormatter={(label) => `Day: ${label}`}
                  contentStyle={{
                    background: 'var(--surface)',
                    border: '1px solid var(--line)',
                    borderRadius: '12px',
                  }}
                />
                <Line
                  type="monotone"
                  dataKey="mood"
                  stroke="var(--brand)"
                  strokeWidth={3}
                  dot={{ r: 4, fill: 'var(--brand)' }}
                  activeDot={{ r: 6 }}
                  connectNulls={false}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
        ) : (
          <div className="dashboard-empty-state">
            <h3>Your trend chart will show up after your first log.</h3>
            <p className="muted">Add a mood check-in today to start seeing a 7-day line.</p>
          </div>
        )}
      </article>

      <div className="dashboard-lower-grid">
        <article className="card dashboard-insight-card">
          <div className="card-header">
            <div>
              <h2>Latest AI insight</h2>
              <p className="muted dashboard-section-copy">Your most recent prediction and next-step nudges.</p>
            </div>
            <Link to="/insights" className="dashboard-text-link">
              See full insight
            </Link>
          </div>

          {data.latestInsight ? (
            <div className="dashboard-insight-body">
              <p className="dashboard-insight-prediction">{data.latestInsight.prediction}</p>
              <p className="muted dashboard-insight-meta">
                Generated {formatDateTime(data.latestInsight.created_at)}
              </p>

              <div className="chip-row">
                {firstTwoSuggestions.map((suggestion) => (
                  <span key={suggestion} className="chip">
                    {suggestion}
                  </span>
                ))}
              </div>

              {!firstTwoSuggestions.length ? (
                <p className="muted">No suggestions were attached to this insight.</p>
              ) : null}
            </div>
          ) : (
            <div className="dashboard-empty-state compact">
              <h3>No insight yet</h3>
              <p className="muted">
                {hasLogs
                  ? 'Visit Insights to generate your first AI summary from recent logs.'
                  : 'Start with a few logs, then AI insight summaries will appear here.'}
              </p>
            </div>
          )}
        </article>

        <article className="card dashboard-recent-card">
          <div className="card-header">
            <div>
              <h2>Recent logs</h2>
              <p className="muted dashboard-section-copy">Your latest five entries at a glance.</p>
            </div>
            <Link to="/logs" className="dashboard-text-link">
              View all logs
            </Link>
          </div>

          {data.recentLogs.length ? (
            <div className="dashboard-log-list">
              {data.recentLogs.map((entry) => (
                <Link key={entry.id} to={`/logs/${entry.id}/edit`} className="dashboard-log-item">
                  <div className="dashboard-log-row">
                    <strong>{formatDate(entry.date)}</strong>
                    <span className="mood-chip">{moodToEmoji(entry.mood)}</span>
                  </div>

                  <div className="chip-row compact">
                    {entry.habits.slice(0, 4).map((habit) => (
                      <span key={habit} className="chip">
                        {habit}
                      </span>
                    ))}
                    {!entry.habits.length ? <span className="muted">No habits tagged</span> : null}
                  </div>
                </Link>
              ))}
            </div>
          ) : (
            <div className="dashboard-empty-state compact">
              <h3>No logs yet</h3>
              <p className="muted">Your recent entries will show up here once you start journaling.</p>
            </div>
          )}
        </article>
      </div>
    </section>
  )
}
