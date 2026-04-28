import { useQuery } from '@tanstack/react-query'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'
import type { LogEntry } from '../../lib/types'
import { formatDate, moodToEmoji } from '../../lib/date'

export function DashboardPage() {
  const { user } = useAuth()
  const navigate = useNavigate()

  const logsQuery = useQuery({
    queryKey: ['dashboard-streak', user?.id],
    queryFn: async () => {
      if (!user) return []
      const { data, error } = await supabase
        .from('log_entries')
        .select('id, date, mood, notes, habits')
        .eq('user_id', user.id)
        .order('date', { ascending: false })
      if (error) throw error
      return data as LogEntry[]
    },
    enabled: !!user,
  })

  const recentLogsQuery = useQuery({
    queryKey: ['logs', user?.id],
    queryFn: async () => {
      if (!user) return []
      const { data, error } = await supabase
        .from('log_entries')
        .select('id, date, mood, notes')
        .eq('user_id', user.id)
        .order('date', { ascending: false })
        .limit(3)
      if (error) throw error
      return data as LogEntry[]
    },
    enabled: !!user,
  })

  const insightQuery = useQuery({
    queryKey: ['dashboard-insight', user?.id],
    queryFn: async () => {
      if (!user) return null
      const { data, error } = await supabase
        .from('ai_insights')
        .select('id, prediction, created_at')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle()
      if (error) throw error
      return data
    },
    enabled: !!user,
  })

  // Calculate mood streak
  const calculateStreak = (logs: LogEntry[]): { streak: number; calendar: boolean[] } => {
    const streak = { streak: 0, calendar: Array(14).fill(false) }

    if (!logs.length) return streak

    const today = new Date()
    today.setHours(0, 0, 0, 0)

    const logsByDate = new Map<string, boolean>()
    for (const log of logs) {
      const logDate = new Date(log.date)
      logDate.setHours(0, 0, 0, 0)
      const dateStr = logDate.toISOString().split('T')[0]
      logsByDate.set(dateStr, true)
    }

    // Build 14-day calendar
    for (let i = 13; i >= 0; i--) {
      const date = new Date(today)
      date.setDate(date.getDate() - i)
      const dateStr = date.toISOString().split('T')[0]
      streak.calendar[13 - i] = logsByDate.has(dateStr)
    }

    // Count consecutive days from today going backwards
    let current = new Date(today)
    while (true) {
      const dateStr = current.toISOString().split('T')[0]
      if (!logsByDate.has(dateStr)) break
      streak.streak++
      current.setDate(current.getDate() - 1)
    }

    return streak
  }

  const streak = logsQuery.data ? calculateStreak(logsQuery.data) : { streak: 0, calendar: Array(14).fill(false) }

  if (!user) {
    return null
  }

  return (
    <section className="feature-grid">
      {/* Mood Streak Card */}
      <article className="card">
        <div className="card-header">
          <h3>Mood Streak</h3>
        </div>
        <div className="card-content">
          <div className="streak-count">
            <p className="muted">Current streak</p>
            <h2>{streak.streak} days</h2>
          </div>
          <div className="calendar-mini">
            {streak.calendar.map((hasEntry, idx) => (
              <div key={idx} className={`calendar-day ${hasEntry ? 'logged' : 'missed'}`} title={`Day ${idx + 1}`}>
                {hasEntry ? '●' : '◯'}
              </div>
            ))}
          </div>
        </div>
      </article>

      {/* Recent Logs Card */}
      <article className="card">
        <div className="card-header">
          <h3>Recent Logs</h3>
        </div>
        <div className="card-content">
          {recentLogsQuery.isLoading && <p className="muted">Loading…</p>}
          {recentLogsQuery.data && recentLogsQuery.data.length === 0 && <p className="muted">No logs yet</p>}
          {recentLogsQuery.data && recentLogsQuery.data.length > 0 && (
            <div className="list-card">
              {recentLogsQuery.data.map((log) => (
                <div
                  key={log.id}
                  className="list-item"
                  onClick={() => navigate(`/logs/${log.id}/edit`)}
                  style={{ cursor: 'pointer' }}
                >
                  <span className="muted">{formatDate(new Date(log.date))}</span>
                  <span>{moodToEmoji(log.mood)}</span>
                  <span className="muted">{log.notes ? log.notes.substring(0, 80) : 'No notes'}</span>
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
              <button type="button" onClick={() => navigate('/insights')}>
                View full insight
              </button>
            </>
          ) : (
            <>
              <p className="muted">No insights yet</p>
              <button type="button" onClick={() => navigate('/insights')}>
                Generate insights
              </button>
            </>
          )}
        </div>
      </article>
    </section>
  )
}
