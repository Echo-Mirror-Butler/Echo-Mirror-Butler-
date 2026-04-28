import { Link } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'
import type { LogEntry, Insight } from '../../lib/types'
import { formatDate, moodToEmoji } from '../../lib/date'

type StreakResult = {
  streak: number
  lastLogDate: string | null
}

type RecentLogsResult = {
  rows: LogEntry[]
  count: number
}

async function fetchStreak(userId: string): Promise<StreakResult> {
  const { data, error } = await supabase
    .from('log_entries')
    .select('date')
    .eq('user_id', userId)
    .order('date', { ascending: false })
    .limit(365)

  if (error) {
    throw error
  }

  const dates = ((data ?? []) as { date: string }[])
    .map((row) => new Date(row.date).toISOString().split('T')[0])
    .filter((value, index, self) => self.indexOf(value) === index)

  if (dates.length === 0) {
    return { streak: 0, lastLogDate: null }
  }

  let streak = 0
  const today = new Date().toISOString().split('T')[0]
  const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0]

  let checkDate = dates.includes(today)
    ? today
    : dates.includes(yesterday)
      ? yesterday
      : dates[0]

  const sortedDates = dates.sort().reverse()

  for (const dateStr of sortedDates) {
    if (dateStr === checkDate) {
      streak++
      const d = new Date(checkDate)
      d.setDate(d.getDate() - 1)
      checkDate = d.toISOString().split('T')[0]
    } else {
      break
    }
  }

  return { streak, lastLogDate: sortedDates[0] ?? null }
}

async function fetchRecentLogs(userId: string): Promise<RecentLogsResult> {
  const { data, error, count } = await supabase
    .from('log_entries')
    .select('*', { count: 'exact' })
    .eq('user_id', userId)
    .order('date', { ascending: false })
    .limit(3)

  if (error) {
    throw error
  }

  return {
    rows: ((data ?? []) as LogEntry[]).map((entry) => ({
      ...entry,
      habits: Array.isArray(entry.habits) ? entry.habits : [],
    })),
    count: count ?? 0,
  }
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
    return null
  }

  return (data as Insight) ?? null
}

export function DashboardPage() {
  const { user } = useAuth()

  const streakQuery = useQuery({
    queryKey: ['dashboard-streak', user?.id],
    queryFn: () => fetchStreak(user!.id),
    enabled: Boolean(user?.id),
  })

  const logsQuery = useQuery({
    queryKey: ['dashboard-recent-logs', user?.id],
    queryFn: () => fetchRecentLogs(user!.id),
    enabled: Boolean(user?.id),
  })

  const insightQuery = useQuery({
    queryKey: ['dashboard-insight', user?.id],
    queryFn: () => fetchLatestInsight(user!.id),
    enabled: Boolean(user?.id),
  })

  if (!user) {
    return null
  }

  const streak = streakQuery.data?.streak ?? 0
  const recentLogs = logsQuery.data?.rows ?? []
  const latestInsight = insightQuery.data ?? null

  return (
    <section className="feature-grid dashboard-grid">
      {/* Mood Streak Card */}
      <article className="card">
        <h2>Mood Streak</h2>
        {streakQuery.isLoading ? (
          <div className="skeleton-line large" />
        ) : (
          <>
            <p className="balance-number">{streak} day{streak !== 1 ? 's' : ''}</p>
            <p className="muted">
              {streak > 0
                ? 'Keep logging daily to maintain your streak!'
                : 'Log today to start your streak.'}
            </p>
            {streakQuery.data?.lastLogDate ? (
              <p className="muted" style={{ fontSize: '0.85rem' }}>
                Last log: {formatDate(streakQuery.data.lastLogDate)}
              </p>
            ) : null}
          </>
        )}
      </article>

      {/* Recent Logs Preview */}
      <article className="card">
        <div className="card-header">
          <h2>Recent Logs</h2>
          <Link to="/logs" className="chip">
            View All
          </Link>
        </div>
        <div className="list-stack">
          {logsQuery.isLoading ? (
            <>
              <div className="skeleton-line" />
              <div className="skeleton-line" />
              <div className="skeleton-line" />
            </>
          ) : recentLogs.length > 0 ? (
            recentLogs.map((entry) => (
              <Link
                to={`/logs/${entry.id}/edit`}
                className="list-card"
                key={entry.id}
              >
                <div className="list-card-row">
                  <strong>{formatDate(entry.date)}</strong>
                  <span className="mood-chip">Mood {moodToEmoji(entry.mood)}</span>
                </div>
                <div className="chip-row compact">
                  {entry.habits.slice(0, 3).map((habit) => (
                    <span className="chip" key={habit}>
                      {habit}
                    </span>
                  ))}
                </div>
                <p className="muted note-preview">
                  {entry.notes?.slice(0, 80) || 'No note'}
                </p>
              </Link>
            ))
          ) : (
            <p className="muted">No log entries yet.</p>
          )}
        </div>
      </article>

      {/* Latest AI Insight Summary */}
      <article className="card full-width">
        <div className="card-header">
          <h2>Latest AI Insight</h2>
          <Link to="/insights" className="chip">
            View All
          </Link>
        </div>
        {insightQuery.isLoading ? (
          <div className="skeleton-line large" />
        ) : latestInsight ? (
          <>
            <p>{latestInsight.prediction.slice(0, 200)}...</p>
            <p className="muted" style={{ fontSize: '0.85rem' }}>
              Generated: {formatDate(latestInsight.created_at)}
            </p>
          </>
        ) : (
          <div className="empty-state">
            <p className="muted">No AI insights generated yet.</p>
            <Link to="/insights" className="chip">
              Generate Insight
            </Link>
          </div>
        )}
      </article>
    </section>
  )
}
