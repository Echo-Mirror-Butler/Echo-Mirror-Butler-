import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { useQuery, keepPreviousData } from '@tanstack/react-query'
import { useEffect, useState, useRef, useMemo } from 'react'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'
import type { LogEntry } from '../../lib/types'
import { formatDate, moodToEmoji, toDateInputValue } from '../../lib/date'

const LOGS_PAGE_SIZE = 10
const LOGS_SCROLL_STORAGE_KEY = 'echomirror:logs-scroll-y'
const MOOD_EMOJIS = ['😞', '😕', '😐', '🙂', '😄'] as const

type LogListResult = {
  rows: LogEntry[]
  count: number
  totalCount: number
}

type LogFilters = {
  mood: number | null
  habit: string
  dateFrom: string
  dateTo: string
}

function filtersToParams(f: LogFilters): Record<string, string> {
  const p: Record<string, string> = {}
  if (f.mood !== null) p.mood = String(f.mood)
  if (f.habit) p.habit = f.habit
  if (f.dateFrom) p.date_from = f.dateFrom
  if (f.dateTo) p.date_to = f.dateTo
  return p
}

function filtersFromSearchParams(sp: URLSearchParams): LogFilters {
  return {
    mood: (() => {
      const v = Number(sp.get('mood'))
      return Number.isInteger(v) && v >= 1 && v <= 5 ? v : null
    })(),
    habit: sp.get('habit') ?? '',
    dateFrom: sp.get('date_from') ?? '',
    dateTo: sp.get('date_to') ?? '',
  }
}

function hasActiveFilters(f: LogFilters): boolean {
  return f.mood !== null || f.habit !== '' || f.dateFrom !== '' || f.dateTo !== ''
}

async function fetchLogs(
  userId: string,
  page: number,
  filters: LogFilters,
): Promise<LogListResult> {
  const start = (page - 1) * LOGS_PAGE_SIZE
  const end = start + LOGS_PAGE_SIZE - 1
  const hasFilters = hasActiveFilters(filters)

  // Build the filtered query
  let filteredQuery = supabase
    .from('log_entries')
    .select('*', { count: 'exact' })
    .eq('user_id', userId)
    .order('date', { ascending: false })

  if (filters.mood !== null) {
    filteredQuery = filteredQuery.eq('mood', filters.mood)
  }

  if (filters.habit) {
    filteredQuery = filteredQuery.contains('habits', [filters.habit])
  }

  if (filters.dateFrom) {
    const fromIso = new Date(`${filters.dateFrom}T00:00:00.000Z`).toISOString()
    filteredQuery = filteredQuery.gte('date', fromIso)
  }
  if (filters.dateTo) {
    const toIso = new Date(`${filters.dateTo}T23:59:59.999Z`).toISOString()
    filteredQuery = filteredQuery.lte('date', toIso)
  }

  // Fetch total (unfiltered) count in parallel when filters are active
  let totalCount = 0
  if (hasFilters) {
    const { count: unfilteredCount, error: countError } = await supabase
      .from('log_entries')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId)

    if (!countError) {
      totalCount = unfilteredCount ?? 0
    }
  }

  const { data, count, error } = await filteredQuery.range(start, end)

  if (error) {
    throw error
  }

  return {
    rows: ((data ?? []) as LogEntry[]).map((entry) => ({
      ...entry,
      habits: Array.isArray(entry.habits) ? entry.habits : [],
    })),
    count: count ?? 0,
    totalCount: hasFilters ? totalCount : (count ?? 0),
  }
}

async function fetchUserHabits(userId: string): Promise<string[]> {
  const { data, error } = await supabase
    .rpc('get_distinct_habits', { p_user_id: userId })

  if (error) {
    // Fallback: query all habits and flatten
    const { data: fallback, error: fallbackError } = await supabase
      .from('log_entries')
      .select('habits')
      .eq('user_id', userId)
      .not('habits', 'is', null)

    if (fallbackError) throw fallbackError

    const all = new Set<string>()
    for (const row of (fallback ?? []) as { habits: string[] }[]) {
      if (Array.isArray(row.habits)) {
        for (const h of row.habits) {
          if (h) all.add(h)
        }
      }
    }
    return [...all].sort()
  }

  return (data ?? []) as string[]
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
  const [exportFormat, setExportFormat] = useState<'csv' | 'json'>('csv')
  const [habitAutocompleteOpen, setHabitAutocompleteOpen] = useState(false)
  const habitInputRef = useRef<HTMLInputElement>(null)
  const autocompleteRef = useRef<HTMLDivElement>(null)

  // Parse filters from URL
  const filters = useMemo(() => filtersFromSearchParams(searchParams), [searchParams])

  const pageParam = Number(searchParams.get('page') ?? '1')
  const page = Number.isInteger(pageParam) && pageParam > 0 ? pageParam : 1

  const setFilters = (next: Partial<LogFilters>) => {
    const merged = { ...filters, ...next }
    const nextParams = new URLSearchParams()

    // Set filter params
    const fp = filtersToParams(merged)
    for (const [k, v] of Object.entries(fp)) {
      nextParams.set(k, v)
    }

    // Reset to page 1 when filters change
    setSearchParams(nextParams, { replace: true })
  }

  const clearFilters = () => {
    setSearchParams(new URLSearchParams(), { replace: true })
  }

  const setPage = (nextPage: number) => {
    const nextParams = new URLSearchParams(searchParams)

    // Preserve filter params but update page
    const fp = filtersToParams(filters)
    for (const [k, v] of Object.entries(fp)) {
      nextParams.set(k, v)
    }

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

      const entries = data ?? []
      const dateStr = new Date().toISOString().slice(0, 10)

      if (exportFormat === 'json') {
        const json = JSON.stringify(entries, null, 2)
        const blob = new Blob([json], { type: 'application/json' })
        const url = URL.createObjectURL(blob)
        const a = document.createElement('a')
        a.href = url
        a.download = `echomirror-logs-${dateStr}.json`
        a.click()
        URL.revokeObjectURL(url)
      } else {
        const header = 'date,mood,habits,notes,created_at'
        const rows = entries.map((e) =>
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
        a.download = `echomirror-logs-${dateStr}.csv`
        a.click()
        URL.revokeObjectURL(url)
      }
    } catch (err) {
      console.error(err)
      setExportError('Failed to export logs')
    } finally {
      setIsExporting(false)
    }
  }

  // Fetch user's distinct habits for autocomplete
  const habitsQuery = useQuery({
    queryKey: ['user-habits', user?.id],
    queryFn: () => fetchUserHabits(user!.id),
    enabled: Boolean(user?.id),
    staleTime: 60_000,
  })

  const allUserHabits = habitsQuery.data ?? []

  // Filter habits based on input
  const filteredHabitSuggestions = useMemo(() => {
    if (!filters.habit) return allUserHabits.slice(0, 20)
    const q = filters.habit.toLowerCase()
    return allUserHabits
      .filter((h) => h.toLowerCase().includes(q))
      .slice(0, 20)
  }, [allUserHabits, filters.habit])

  // Close autocomplete on outside click
  useEffect(() => {
    const handleClick = (e: MouseEvent) => {
      if (
        autocompleteRef.current &&
        !autocompleteRef.current.contains(e.target as Node) &&
        habitInputRef.current &&
        !habitInputRef.current.contains(e.target as Node)
      ) {
        setHabitAutocompleteOpen(false)
      }
    }
    document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [])

  const logsQuery = useQuery({
    queryKey: ['logs', user?.id, page, filters],
    queryFn: () => fetchLogs(user!.id, page, filters),
    enabled: Boolean(user?.id),
    placeholderData: keepPreviousData,
  })
  const totalPages = Math.max(1, Math.ceil((logsQuery.data?.count ?? 0) / LOGS_PAGE_SIZE))
  const hasFilters = hasActiveFilters(filters)
  const displayedCount = logsQuery.data?.rows.length ?? 0
  const totalCount = logsQuery.data?.totalCount ?? 0

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

  // Close autocomplete on Escape
  useEffect(() => {
    if (!habitAutocompleteOpen) return
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setHabitAutocompleteOpen(false)
    }
    window.addEventListener('keydown', handleKey)
    return () => window.removeEventListener('keydown', handleKey)
  }, [habitAutocompleteOpen])

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
          <div style={{ display: 'flex', gap: '0.4rem', alignItems: 'center' }}>
            <div style={{ display: 'flex', gap: '0.15rem', fontSize: '0.82rem' }}>
              <button
                type="button"
                onClick={() => setExportFormat('csv')}
                style={{
                  padding: '0.4rem 0.55rem',
                  background: exportFormat === 'csv' ? 'var(--brand)' : 'var(--surface-soft)',
                  color: exportFormat === 'csv' ? '#fff' : 'var(--text)',
                  border: '1px solid var(--line)',
                  borderRadius: '8px 0 0 8px',
                  fontSize: '0.82rem',
                }}
              >
                CSV
              </button>
              <button
                type="button"
                onClick={() => setExportFormat('json')}
                style={{
                  padding: '0.4rem 0.55rem',
                  background: exportFormat === 'json' ? 'var(--brand)' : 'var(--surface-soft)',
                  color: exportFormat === 'json' ? '#fff' : 'var(--text)',
                  border: '1px solid var(--line)',
                  borderRadius: '0 8px 8px 0',
                  fontSize: '0.82rem',
                }}
              >
                JSON
              </button>
            </div>
            <button type="button" className="secondary" onClick={handleExport} disabled={isExporting}>
              {isExporting ? 'Exporting…' : 'Export'}
            </button>
          </div>
        </div>
        {exportError && <p className="error-text" style={{ padding: '0 1.5rem' }}>{exportError}</p>}

        {/* ── Filter bar ── */}
        <div style={{
          padding: '0.75rem 1.5rem',
          borderBottom: '1px solid var(--line)',
          display: 'flex',
          flexWrap: 'wrap',
          gap: '0.75rem',
          alignItems: 'flex-end',
        }}>
          {/* Mood filter */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.3rem' }}>
            <span className="field-label" style={{ fontSize: '0.75rem' }}>Mood</span>
            <div style={{ display: 'flex', gap: '0.25rem' }}>
              {MOOD_EMOJIS.map((emoji, idx) => {
                const value = idx + 1
                const isActive = filters.mood === value
                return (
                  <button
                    key={value}
                    type="button"
                    onClick={() => setFilters({ mood: isActive ? null : value })}
                    aria-label={`Filter mood ${value}`}
                    title={`Mood ${value}`}
                    style={{
                      fontSize: '1.15rem',
                      padding: '0.35rem 0.5rem',
                      minWidth: '36px',
                      opacity: isActive ? 1 : 0.5,
                      transform: isActive ? 'scale(1.1)' : 'scale(1)',
                      transition: 'opacity 0.15s, transform 0.15s',
                      background: isActive ? 'var(--brand)' : 'var(--surface-soft)',
                      border: isActive ? '2px solid var(--brand-strong)' : '1px solid var(--line)',
                      borderRadius: '8px',
                      cursor: 'pointer',
                    }}
                  >
                    {emoji}
                  </button>
                )
              })}
            </div>
          </div>

          {/* Habit filter with autocomplete */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.3rem', position: 'relative' }}>
            <span className="field-label" style={{ fontSize: '0.75rem' }}>Habit</span>
            <input
              ref={habitInputRef}
              type="text"
              value={filters.habit}
              onChange={(e) => {
                setFilters({ habit: e.target.value })
                setHabitAutocompleteOpen(true)
              }}
              onFocus={() => setHabitAutocompleteOpen(true)}
              placeholder="Filter by habit..."
              style={{
                width: '160px',
                padding: '0.4rem 0.55rem',
                fontSize: '0.85rem',
                margin: 0,
              }}
            />
            {habitAutocompleteOpen && filteredHabitSuggestions.length > 0 && (
              <div
                ref={autocompleteRef}
                style={{
                  position: 'absolute',
                  top: '100%',
                  left: 0,
                  right: 0,
                  zIndex: 10,
                  background: 'var(--surface)',
                  border: '1px solid var(--line)',
                  borderRadius: '8px',
                  boxShadow: 'var(--shadow)',
                  maxHeight: '180px',
                  overflowY: 'auto',
                  marginTop: '2px',
                }}
              >
                {filteredHabitSuggestions.map((habit) => (
                  <button
                    key={habit}
                    type="button"
                    onClick={() => {
                      setFilters({ habit })
                      setHabitAutocompleteOpen(false)
                      habitInputRef.current?.blur()
                    }}
                    style={{
                      display: 'block',
                      width: '100%',
                      textAlign: 'left',
                      padding: '0.45rem 0.65rem',
                      fontSize: '0.85rem',
                      background: 'transparent',
                      border: 'none',
                      borderRadius: 0,
                      color: 'var(--text)',
                      cursor: 'pointer',
                    }}
                    onMouseEnter={(e) => (e.currentTarget.style.background = 'var(--surface-soft)')}
                    onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
                  >
                    {habit}
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* Date from */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.3rem' }}>
            <span className="field-label" style={{ fontSize: '0.75rem' }}>From</span>
            <input
              type="date"
              value={filters.dateFrom}
              onChange={(e) => setFilters({ dateFrom: e.target.value })}
              style={{
                padding: '0.4rem 0.55rem',
                fontSize: '0.85rem',
                width: '140px',
                margin: 0,
              }}
            />
          </div>

          {/* Date to */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.3rem' }}>
            <span className="field-label" style={{ fontSize: '0.75rem' }}>To</span>
            <input
              type="date"
              value={filters.dateTo}
              onChange={(e) => setFilters({ dateTo: e.target.value })}
              style={{
                padding: '0.4rem 0.55rem',
                fontSize: '0.85rem',
                width: '140px',
                margin: 0,
              }}
            />
          </div>

          {/* Clear filters */}
          {hasFilters && (
            <button
              type="button"
              onClick={clearFilters}
              style={{
                padding: '0.4rem 0.75rem',
                fontSize: '0.82rem',
                background: 'transparent',
                border: '1px solid var(--line)',
                borderRadius: '8px',
                color: 'var(--muted)',
                cursor: 'pointer',
                whiteSpace: 'nowrap',
              }}
            >
              Clear filters
            </button>
          )}
        </div>

        {/* ── Filtered count ── */}
        {hasFilters && logsQuery.data && (
          <div style={{
            padding: '0.5rem 1.5rem',
            fontSize: '0.82rem',
            color: 'var(--muted)',
            borderBottom: '1px solid var(--line)',
          }}>
            Showing {displayedCount} of {totalCount} entries
          </div>
        )}

        <div className="list-stack">
          {logsQuery.data?.rows.map((entry) => (
            <Link
              to={`/logs/${entry.id}`}
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
          {!logsQuery.data?.rows.length && !logsQuery.isLoading && hasFilters ? (
            <p className="muted" style={{ padding: '1rem 1.5rem' }}>
              No entries match the current filters.{' '}
              <button
                type="button"
                onClick={clearFilters}
                style={{
                  background: 'none',
                  border: 'none',
                  color: 'var(--brand)',
                  cursor: 'pointer',
                  fontSize: 'inherit',
                  padding: 0,
                  textDecoration: 'underline',
                }}
              >
                Clear filters
              </button>
            </p>
          ) : null}
          {!logsQuery.data?.rows.length && !logsQuery.isLoading && !hasFilters ? (
            <div style={{ textAlign: 'center', padding: '2.5rem 1.5rem' }}>
              <div style={{ fontSize: '3rem', marginBottom: '0.75rem' }} aria-hidden="true">📓</div>
              <h3 style={{ fontFamily: "'Fraunces', serif", margin: '0 0 0.4rem', fontSize: '1.3rem' }}>No entries yet</h3>
              <p className="muted" style={{ margin: '0 0 1.2rem', fontSize: '0.9rem', maxWidth: '28ch', marginInline: 'auto' }}>
                Start logging your mood to track patterns and earn ECHO tokens
              </p>
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
                Log Today's Mood
              </button>
            </div>
          ) : null}
          {logsQuery.data?.rows.length && page >= totalPages && !logsQuery.isFetching ? (
            <p className="muted" style={{ padding: '0.5rem 0' }}>No more entries.</p>
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