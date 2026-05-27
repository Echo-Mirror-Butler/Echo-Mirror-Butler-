import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { useQuery, keepPreviousData } from '@tanstack/react-query'
import { useEffect, useState } from 'react'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'
import type { LogEntry } from '../../lib/types'
import { formatDate, moodToEmoji, toDateInputValue } from '../../lib/date'

const LOGS_PAGE_SIZE = 10
const LOGS_SCROLL_STORAGE_KEY = 'echomirror:logs-scroll-y'

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
  const [searchParams, setSearchParams] = useSearchParams()
  const [isExporting, setIsExporting] = useState(false)
  const [exportError, setExportError] = useState<string | null>(null)

  const pageParam = Number(searchParams.get('page') ?? '1')
  const page = Number.isInteger(pageParam) && pageParam > 0 ? pageParam : 1

  const setPage = (nextPage: number) => {
    const nextParams = new URLSearchParams(searchParams)
    if (nextPage <= 1) {
      nextParams.delete('page')
    } else {
      nextParams.set('page', String(nextPage))
    }
    setSearchParams(nextParams)
  }

  const rememberScrollPosition = () => {
    sessionStorage.setItem(LOGS_SCROLL_STORAGE_KEY, String(window.scrollY))
  }

  const handleExport = async () => {
    if (!user) return
    try {
      setIsExporting(true)
      setExportError(null)

      const { data, error } = await supabase
        .from('log_entries')
        .select('date, mood, habits, notes, created_at')
        .eq('user_id', user.id)
        .order('date', { ascending: false })

      if (error) throw error

      const header = 'date,mood,habits,notes,created_at'

      const rows = (data ?? []).map((e) =>
        [
          e.date,
          e.mood ?? '',
          JSON.stringify(e.habits),
          (e.notes ?? '').replace(/,/g, ';'),
          e.created_at,
        ].join(','),
      )

      const csv = [header, ...rows].join('\n')

      const blob = new Blob([csv], { type: 'text/csv' })
      const url = URL.createObjectURL(blob)

      const a = document.createElement('a')
      a.href = url
      a.download = `echomirror-logs-${new Date().toISOString().slice(0, 10)}.csv`
      a.click()

      URL.revokeObjectURL(url)
    } catch (err) {
      console.error(err)
      setExportError('Failed to export logs')
    } finally {
      setIsExporting(false)
    }
  }

  const logsQuery = useQuery({
    queryKey: ['logs', user?.id, page],
    queryFn: () => fetchLogs(user!.id, page),
    enabled: Boolean(user?.id),
    placeholderData: keepPreviousData,
  })
  const totalPages = Math.max(1, Math.ceil((logsQuery.data?.count ?? 0) / LOGS_PAGE_SIZE))

  useEffect(() => {
    const savedScrollY = sessionStorage.getItem(LOGS_SCROLL_STORAGE_KEY)
    if (!savedScrollY) {
      return
    }

    sessionStorage.removeItem(LOGS_SCROLL_STORAGE_KEY)
    requestAnimationFrame(() => window.scrollTo(0, Number(savedScrollY)))
  }, [page])

  useEffect(() => {
    if (logsQuery.data && page > totalPages) {
      setPage(totalPages)
    }
  }, [logsQuery.data, page, totalPages])

  if (!user) {
    return null
  }

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
          <button type="button" className="secondary" onClick={handleExport} disabled={isExporting}>
            {isExporting ? 'Exporting…' : 'Export CSV'}
          </button>
        </div>
        {exportError && <p className="error-text" style={{ padding: '0 1.5rem' }}>{exportError}</p>}

        <div className="list-stack">
          {logsQuery.data?.rows.map((entry) => (
            <Link
              to={`/logs/${entry.id}/edit`}
              className="list-card"
              key={entry.id}
              onClick={rememberScrollPosition}
            >
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

          {logsQuery.isLoading || logsQuery.isFetching ? <div className="skeleton-line" /> : null}
          {!logsQuery.data?.rows.length && !logsQuery.isLoading ? (
            <p className="muted">No log entries yet.</p>
          ) : null}
          {logsQuery.data?.rows.length && page >= totalPages && !logsQuery.isFetching ? (
            <p className="muted">No more entries.</p>
          ) : null}
        </div>

        <div className="pagination-row">
          <button
            type="button"
            disabled={page <= 1 || logsQuery.isFetching}
            onClick={() => setPage(Math.max(1, page - 1))}
          >
            Prev
          </button>
          <span>
            Page {page} / {totalPages}
          </span>
          <button
            type="button"
            disabled={page >= totalPages || logsQuery.isFetching}
            onClick={() => setPage(Math.min(totalPages, page + 1))}
          >
            Next
          </button>
        </div>
      </article>
    </section>
  )
}
