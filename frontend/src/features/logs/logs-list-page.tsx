import { Link, useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { useState } from 'react'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'
import type { LogEntry } from '../../lib/types'
import { formatDate, moodToEmoji, toDateInputValue } from '../../lib/date'

const LOGS_PAGE_SIZE = 10

type LogListResult = {
  rows: LogEntry[]
  count: number
}

async function fetchLogs(userId: string, page: number): Promise<LogListResult> {
  const start = (page - 1) * LOGS_PAGE_SIZE
  const end = start + LOGS_PAGE_SIZE - 1

  const { data, count, error } = await supabase
    .from('log_entries')
    .select('*', { count: 'exact' })
    .eq('user_id', userId)
    .order('date', { ascending: false })
    .range(start, end)

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

async function findExistingLogIdForDate(userId: string, dateValue: string): Promise<string | null> {
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

export function LogsListPage() {
  const navigate = useNavigate()
  const { user } = useAuth()
  const [page, setPage] = useState(1)

  const logsQuery = useQuery({
    queryKey: ['logs', user?.id, page],
    queryFn: () => fetchLogs(user!.id, page),
    enabled: Boolean(user?.id),
  })

  if (!user) {
    return null
  }

  const totalPages = Math.max(1, Math.ceil((logsQuery.data?.count ?? 0) / LOGS_PAGE_SIZE))

  return (
    <section className="feature-grid logs-grid">
      <article className="card full-width">
        <div className="card-header">
          <h2>Daily Logs</h2>
          <button
            type="button"
            onClick={async () => {
              const today = toDateInputValue(new Date())
              const existingId = await findExistingLogIdForDate(user.id, today)
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

        <div className="list-stack">
          {logsQuery.data?.rows.map((entry) => (
            <Link to={`/logs/${entry.id}/edit`} className="list-card" key={entry.id}>
              <div className="list-card-row">
                <strong>{formatDate(entry.date)}</strong>
                <span className="mood-chip">Mood {moodToEmoji(entry.mood)}</span>
              </div>

              <div className="chip-row compact">
                {entry.habits.slice(0, 5).map((habit) => (
                  <span className="chip" key={habit}>
                    {habit}
                  </span>
                ))}
              </div>

              <p className="muted note-preview">{entry.notes?.slice(0, 120) || 'No note'}</p>
            </Link>
          ))}

          {logsQuery.isLoading ? <div className="skeleton-line" /> : null}
          {!logsQuery.data?.rows.length && !logsQuery.isLoading ? (
            <p className="muted">No log entries yet.</p>
          ) : null}
        </div>

        <div className="pagination-row">
          <button type="button" onClick={() => setPage((prev) => Math.max(1, prev - 1))}>
            Prev
          </button>
          <span>
            Page {page} / {totalPages}
          </span>
          <button type="button" onClick={() => setPage((prev) => Math.min(totalPages, prev + 1))}>
            Next
          </button>
        </div>
      </article>
    </section>
  )
}
