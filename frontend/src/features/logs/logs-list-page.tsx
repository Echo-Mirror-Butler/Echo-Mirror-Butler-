import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient, keepPreviousData } from '@tanstack/react-query'
import { useEffect, useState, useRef, useMemo, type KeyboardEvent as ReactKeyboardEvent, type ReactNode } from 'react'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'
import { useToast } from '../../lib/use-toast'
import type { LogEntry } from '../../lib/types'
import { formatDate, moodToEmoji, toDateInputValue } from '../../lib/date'
import { buildLogsCsv, type LogCsvRow } from './logs-csv'
import {
  parseImportFile,
  toImportRpcPayload,
  type ImportPreview,
  type ImportRow,
} from './logs-import'
import { SORT_OPTIONS, DEFAULT_SORT, isSortOption, splitOnMatch, type SortOption } from './logs-utils'
import { LogImageThumbnail } from './components/log-image-thumbnail'

const LOGS_PAGE_SIZE = 10
const LOGS_SCROLL_STORAGE_KEY = 'echomirror:logs-scroll-y'
const LOGS_SORT_STORAGE_KEY = 'echomirror:logs-sort'
const SEARCH_DEBOUNCE_MS = 300
const HABIT_DEBOUNCE_MS = 300
const HABIT_SUGGESTION_LIMIT = 20
const NOTE_PREVIEW_LENGTH = 120
const MOOD_EMOJIS = ['😞', '😕', '😐', '🙂', '😄'] as const

type LogListResult = {
  rows: LogEntry[]
  count: number
  totalCount: number
}

type LogFilters = {
  mood: number | null
  habits: string[]
  dateFrom: string
  dateTo: string
}

function applyFiltersToParams(params: URLSearchParams, f: LogFilters): void {
  if (f.mood !== null) params.set('mood', String(f.mood))
  for (const habit of f.habits) {
    params.append('habit', habit)
  }
  if (f.dateFrom) params.set('date_from', f.dateFrom)
  if (f.dateTo) params.set('date_to', f.dateTo)
}

function filtersFromSearchParams(sp: URLSearchParams): LogFilters {
  return {
    mood: (() => {
      const v = Number(sp.get('mood'))
      return Number.isInteger(v) && v >= 1 && v <= 5 ? v : null
    })(),
    habits: sp.getAll('habit').filter(Boolean),
    dateFrom: sp.get('date_from') ?? '',
    dateTo: sp.get('date_to') ?? '',
  }
}

function hasActiveFilters(f: LogFilters): boolean {
  return f.mood !== null || f.habits.length > 0 || f.dateFrom !== '' || f.dateTo !== ''
}

function loadStoredSort(): SortOption {
  try {
    const stored = sessionStorage.getItem(LOGS_SORT_STORAGE_KEY)
    return isSortOption(stored) ? stored : DEFAULT_SORT
  } catch {
    return DEFAULT_SORT
  }
}

function downloadCsv(csv: string, filename: string): void {
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.click()
  URL.revokeObjectURL(url)
}

function todayStamp(): string {
  return new Date().toISOString().slice(0, 10)
}

function renderNotePreview(notes: string | null, search: string): ReactNode {
  const preview = notes?.slice(0, NOTE_PREVIEW_LENGTH) || 'No note'
  if (!notes || !search.trim()) {
    return preview
  }
  return splitOnMatch(preview, search).map((segment, index) =>
    segment.match ? <mark key={index}>{segment.text}</mark> : <span key={index}>{segment.text}</span>,
  )
}

async function fetchLogs(
  userId: string,
  page: number,
  filters: LogFilters,
  search: string,
  sort: SortOption,
): Promise<LogListResult> {
  const start = (page - 1) * LOGS_PAGE_SIZE
  const end = start + LOGS_PAGE_SIZE - 1
  const trimmedSearch = search.trim()
  const hasFilters = hasActiveFilters(filters) || trimmedSearch !== ''

  // Build the filtered query
  let filteredQuery = supabase
    .from('log_entries')
    .select('*', { count: 'exact' })
    .eq('user_id', userId)

  // Sorting — mood orders fall back to date (newest) for a stable tiebreak and
  // keep null moods last.
  if (sort === 'mood_desc') {
    filteredQuery = filteredQuery
      .order('mood', { ascending: false, nullsFirst: false })
      .order('date', { ascending: false })
  } else if (sort === 'mood_asc') {
    filteredQuery = filteredQuery
      .order('mood', { ascending: true, nullsFirst: false })
      .order('date', { ascending: false })
  } else if (sort === 'date_asc') {
    filteredQuery = filteredQuery.order('date', { ascending: true })
  } else {
    filteredQuery = filteredQuery.order('date', { ascending: false })
  }

  if (filters.mood !== null) {
    filteredQuery = filteredQuery.eq('mood', filters.mood)
  }

  // A single `contains` with every selected habit applies AND logic (the row's
  // habits must include all of them).
  if (filters.habits.length > 0) {
    filteredQuery = filteredQuery.contains('habits', filters.habits)
  }

  if (trimmedSearch) {
    // Escape LIKE wildcards so `%` and `_` are matched literally.
    const escaped = trimmedSearch.replace(/[\\%_]/g, '\\$&')
    filteredQuery = filteredQuery.ilike('notes', `%${escaped}%`)
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
  const { showToast } = useToast()
  const queryClient = useQueryClient()
  const [searchParams, setSearchParams] = useSearchParams()

  const [isExporting, setIsExporting] = useState(false)
  const [exportError, setExportError] = useState<string | null>(null)
  const [importPreview, setImportPreview] = useState<ImportPreview | null>(null)
  const [importError, setImportError] = useState<string | null>(null)
  const [isImporting, setIsImporting] = useState(false)
  const importInputRef = useRef<HTMLInputElement>(null)

  // Free-text search (kept in component state, debounced before querying)
  const [searchInput, setSearchInput] = useState('')
  const [debouncedSearch, setDebouncedSearch] = useState('')
  const didMountSearch = useRef(false)

  // Sort preference (persisted in sessionStorage so it survives pagination)
  const [sort, setSort] = useState<SortOption>(loadStoredSort)

  // Habit autocomplete
  const [habitInput, setHabitInput] = useState('')
  const [debouncedHabitInput, setDebouncedHabitInput] = useState('')
  const [habitAutocompleteOpen, setHabitAutocompleteOpen] = useState(false)
  const habitInputRef = useRef<HTMLInputElement>(null)
  const autocompleteRef = useRef<HTMLDivElement>(null)

  // Bulk selection
  const [selectedIds, setSelectedIds] = useState<Set<string>>(() => new Set())
  const [isDeleteDialogOpen, setIsDeleteDialogOpen] = useState(false)
  const selectAllRef = useRef<HTMLInputElement>(null)
  const cancelDeleteRef = useRef<HTMLButtonElement>(null)
  const deleteTriggerFocusRef = useRef<HTMLElement | null>(null)

  // Parse filters from URL
  const filters = useMemo(() => filtersFromSearchParams(searchParams), [searchParams])

  const pageParam = Number(searchParams.get('page') ?? '1')
  const page = Number.isInteger(pageParam) && pageParam > 0 ? pageParam : 1

  const setFilters = (next: Partial<LogFilters>) => {
    const merged = { ...filters, ...next }
    const nextParams = new URLSearchParams()
    applyFiltersToParams(nextParams, merged)
    // Reset to page 1 when filters change
    setSearchParams(nextParams, { replace: true })
  }

  const clearFilters = () => {
    setSearchParams(new URLSearchParams(), { replace: true })
  }

  const setPage = (nextPage: number) => {
    const nextParams = new URLSearchParams()
    applyFiltersToParams(nextParams, filters)
    if (nextPage > 1) {
      nextParams.set('page', String(nextPage))
    }
    setSearchParams(nextParams)
  }

  const rememberScrollPosition = () => {
    sessionStorage.setItem(LOGS_SCROLL_STORAGE_KEY, String(window.scrollY))
  }

  const clearSearch = () => {
    setSearchInput('')
    setDebouncedSearch('')
  }

  const handleSortChange = (value: SortOption) => {
    setSort(value)
    try {
      sessionStorage.setItem(LOGS_SORT_STORAGE_KEY, value)
    } catch {
      // sessionStorage may be unavailable (private mode); sorting still works.
    }
    setPage(1)
  }

  const handleExport = async () => {
    if (!user) return
    try {
      setIsExporting(true)
      setExportError(null)

      const { data, error } = await supabase
        .from('log_entries')
        .select('id, date, mood, habits, notes, created_at')
        .eq('user_id', user.id)
        .order('date', { ascending: false })

      if (error) throw error

      const entries = (data ?? []).map((entry) => ({
        ...entry,
        habits: Array.isArray(entry.habits) ? entry.habits : [],
      })) as LogCsvRow[]

      downloadCsv(buildLogsCsv(entries), `echomirror-logs-${todayStamp()}.csv`)
    } catch (err) {
      console.error(err)
      setExportError('Failed to export logs')
    } finally {
      setIsExporting(false)
    }
  }

  const handleImportFile = async (file: File | null) => {
    if (!file) return
    setImportError(null)
    try {
      const text = await file.text()
      const preview = parseImportFile(file.name, text)
      if (preview.uniqueValid.length === 0 && preview.invalid.length > 0) {
        setImportError(preview.invalid[0]?.error ?? 'No valid rows found')
        setImportPreview(preview.uniqueValid.length ? preview : preview)
        return
      }
      setImportPreview(preview)
    } catch (err) {
      console.error(err)
      setImportError('Failed to read import file')
      setImportPreview(null)
    } finally {
      if (importInputRef.current) importInputRef.current.value = ''
    }
  }

  const commitImport = async (rows: ImportRow[]) => {
    if (!user || rows.length === 0) return
    setIsImporting(true)
    setImportError(null)
    try {
      const { data, error } = await supabase.rpc('import_log_entries', {
        p_rows: toImportRpcPayload(rows),
      })
      if (error) throw error
      const result = data as {
        success?: boolean
        inserted?: number
        skipped?: number
        error?: string
        errors?: { row: number; error: string }[]
      }
      if (result?.success === false) {
        setImportError(result.error ?? 'Import failed')
        return
      }
      const inserted = result?.inserted ?? 0
      const skipped = result?.skipped ?? 0
      showToast(
        `Imported ${inserted} log${inserted === 1 ? '' : 's'}` +
          (skipped > 0 ? ` (${skipped} skipped as duplicates)` : ''),
        'success',
      )
      setImportPreview(null)
      await queryClient.invalidateQueries({ queryKey: ['logs'] })
    } catch (err) {
      console.error(err)
      setImportError(err instanceof Error ? err.message : 'Failed to import logs')
    } finally {
      setIsImporting(false)
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

  // Suggestions exclude already-selected habits and are debounced + capped.
  const { habitSuggestions, habitSuggestionsTruncated } = useMemo(() => {
    const q = debouncedHabitInput.toLowerCase()
    const matches = allUserHabits
      .filter((h) => !filters.habits.includes(h))
      .filter((h) => (q ? h.toLowerCase().includes(q) : true))
    return {
      habitSuggestions: matches.slice(0, HABIT_SUGGESTION_LIMIT),
      habitSuggestionsTruncated: matches.length > HABIT_SUGGESTION_LIMIT,
    }
  }, [allUserHabits, debouncedHabitInput, filters.habits])

  const addHabit = (habit: string) => {
    const next = habit.trim()
    if (!next) return
    if (!filters.habits.includes(next)) {
      setFilters({ habits: [...filters.habits, next] })
    }
    setHabitInput('')
    setDebouncedHabitInput('')
    setHabitAutocompleteOpen(false)
    habitInputRef.current?.blur()
  }

  const removeHabit = (habit: string) => {
    setFilters({ habits: filters.habits.filter((h) => h !== habit) })
  }

  const handleHabitKeyDown = (event: ReactKeyboardEvent<HTMLInputElement>) => {
    if (event.key === 'Enter') {
      event.preventDefault()
      addHabit(habitSuggestions[0] ?? habitInput)
    }
  }

  // Debounce the free-text search input
  useEffect(() => {
    const handle = setTimeout(() => setDebouncedSearch(searchInput.trim()), SEARCH_DEBOUNCE_MS)
    return () => clearTimeout(handle)
  }, [searchInput])

  // Reset to the first page whenever the active search term changes
  useEffect(() => {
    if (!didMountSearch.current) {
      didMountSearch.current = true
      return
    }
    setPage(1)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [debouncedSearch])

  // Debounce the habit autocomplete input
  useEffect(() => {
    const handle = setTimeout(() => setDebouncedHabitInput(habitInput.trim()), HABIT_DEBOUNCE_MS)
    return () => clearTimeout(handle)
  }, [habitInput])

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
    queryKey: ['logs', user?.id, page, filters, debouncedSearch, sort],
    queryFn: () => fetchLogs(user!.id, page, filters, debouncedSearch, sort),
    enabled: Boolean(user?.id),
    placeholderData: keepPreviousData,
  })
  const rows = logsQuery.data?.rows ?? []
  const totalPages = Math.max(1, Math.ceil((logsQuery.data?.count ?? 0) / LOGS_PAGE_SIZE))
  const hasFilters = hasActiveFilters(filters)
  const hasSearch = debouncedSearch.trim() !== ''
  const displayedCount = rows.length
  const totalCount = logsQuery.data?.totalCount ?? 0

  // Bulk delete
  const bulkDeleteMutation = useMutation({
    mutationFn: async (ids: string[]) => {
      if (!user) {
        throw new Error('No signed in user found.')
      }
      const { error } = await supabase
        .from('log_entries')
        .delete()
        .eq('user_id', user.id)
        .in('id', ids)

      if (error) throw error
      return ids.length
    },
    onSuccess: async (deletedCount) => {
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ['logs', user?.id] }),
        queryClient.invalidateQueries({ queryKey: ['user-habits', user?.id] }),
      ])
      setSelectedIds(new Set())
      setIsDeleteDialogOpen(false)
      showToast(`${deletedCount} ${deletedCount === 1 ? 'entry' : 'entries'} deleted`, 'success')
    },
    onError: (error: Error) => {
      setIsDeleteDialogOpen(false)
      showToast(error.message || 'Failed to delete entries', 'error')
    },
  })

  const allSelectedOnPage = rows.length > 0 && rows.every((r) => selectedIds.has(r.id))
  const someSelectedOnPage = rows.some((r) => selectedIds.has(r.id))

  const toggleSelectAll = () => {
    setSelectedIds((prev) => {
      const next = new Set(prev)
      if (allSelectedOnPage) {
        for (const r of rows) next.delete(r.id)
      } else {
        for (const r of rows) next.add(r.id)
      }
      return next
    })
  }

  const toggleSelect = (id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev)
      if (next.has(id)) {
        next.delete(id)
      } else {
        next.add(id)
      }
      return next
    })
  }

  const handleBulkExport = () => {
    const selected = rows.filter((r) => selectedIds.has(r.id))
    if (selected.length === 0) return
    downloadCsv(buildLogsCsv(selected), `echomirror-logs-selected-${todayStamp()}.csv`)
  }

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
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [logsQuery.data, page, totalPages])

  // Clear the selection whenever the visible page of rows changes
  useEffect(() => {
    setSelectedIds(new Set())
  }, [page, debouncedSearch, sort, filters])

  // Keep the "select all" checkbox in its indeterminate state when only some
  // rows on the page are selected.
  useEffect(() => {
    if (selectAllRef.current) {
      selectAllRef.current.indeterminate = someSelectedOnPage && !allSelectedOnPage
    }
  }, [someSelectedOnPage, allSelectedOnPage])

  // Close autocomplete on Escape
  useEffect(() => {
    if (!habitAutocompleteOpen) return
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setHabitAutocompleteOpen(false)
    }
    window.addEventListener('keydown', handleKey)
    return () => window.removeEventListener('keydown', handleKey)
  }, [habitAutocompleteOpen])

  // Bulk-delete dialog: move focus into it on open, close on Escape, and
  // restore focus to the element that opened it on close.
  useEffect(() => {
    if (!isDeleteDialogOpen) return
    cancelDeleteRef.current?.focus()
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setIsDeleteDialogOpen(false)
    }
    window.addEventListener('keydown', handleKey)
    return () => {
      window.removeEventListener('keydown', handleKey)
      deleteTriggerFocusRef.current?.focus?.()
    }
  }, [isDeleteDialogOpen])

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
          <button
            type="button"
            className="secondary"
            onClick={() => importInputRef.current?.click()}
            disabled={isImporting}
          >
            Import CSV/JSON
          </button>
          <input
            ref={importInputRef}
            type="file"
            accept=".csv,.json,text/csv,application/json"
            style={{ display: 'none' }}
            aria-label="Import mood logs file"
            onChange={(e) => void handleImportFile(e.target.files?.[0] ?? null)}
          />
        </div>
        {exportError && <p className="error-text" style={{ padding: '0 1.5rem' }}>{exportError}</p>}
        {importError && <p className="error-text" style={{ padding: '0 1.5rem' }}>{importError}</p>}
        {importPreview && (
          <div
            role="dialog"
            aria-label="Import preview"
            style={{
              margin: '0.75rem 1.5rem',
              padding: '1rem',
              border: '1px solid var(--line)',
              borderRadius: 12,
              background: 'var(--surface-soft)',
            }}
          >
            <h3 style={{ margin: '0 0 0.5rem', fontSize: '1rem' }}>Import preview</h3>
            <p style={{ margin: '0 0 0.75rem', fontSize: '0.875rem', color: 'var(--muted)' }}>
              {importPreview.uniqueValid.length} valid row
              {importPreview.uniqueValid.length === 1 ? '' : 's'} ready
              {importPreview.invalid.length > 0
                ? ` · ${importPreview.invalid.length} invalid skipped`
                : ''}
              . Existing logs for the same date are not duplicated.
            </p>
            {importPreview.uniqueValid.length > 0 && (
              <div style={{ maxHeight: 180, overflow: 'auto', marginBottom: '0.75rem' }}>
                <table style={{ width: '100%', fontSize: '0.8rem', borderCollapse: 'collapse' }}>
                  <thead>
                    <tr>
                      <th align="left">Date</th>
                      <th align="left">Mood</th>
                      <th align="left">Habits</th>
                      <th align="left">Notes</th>
                    </tr>
                  </thead>
                  <tbody>
                    {importPreview.uniqueValid.slice(0, 20).map((row) => (
                      <tr key={row.date}>
                        <td>{row.date}</td>
                        <td>{row.mood ?? '—'}</td>
                        <td>{row.habits.join('; ') || '—'}</td>
                        <td>{row.notes?.slice(0, 40) || '—'}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
                {importPreview.uniqueValid.length > 20 && (
                  <p style={{ fontSize: '0.75rem', color: 'var(--muted)' }}>
                    …and {importPreview.uniqueValid.length - 20} more
                  </p>
                )}
              </div>
            )}
            {importPreview.invalid.length > 0 && (
              <ul style={{ fontSize: '0.8rem', color: 'var(--danger, #b91c1c)', margin: '0 0 0.75rem' }}>
                {importPreview.invalid.slice(0, 5).map((err) =>
                  err.ok ? null : (
                    <li key={`${err.row}-${err.error}`}>
                      Row {err.row}: {err.error}
                    </li>
                  ),
                )}
              </ul>
            )}
            <div style={{ display: 'flex', gap: '0.5rem' }}>
              <button
                type="button"
                disabled={isImporting || importPreview.uniqueValid.length === 0}
                onClick={() => void commitImport(importPreview.uniqueValid)}
              >
                {isImporting ? 'Importing…' : `Import ${importPreview.uniqueValid.length} rows`}
              </button>
              <button
                type="button"
                className="secondary"
                disabled={isImporting}
                onClick={() => {
                  setImportPreview(null)
                  setImportError(null)
                }}
              >
                Cancel
              </button>
            </div>
          </div>
        )}

        {/* ── Search bar ── */}
        <div style={{ padding: '0.75rem 1.5rem 0', position: 'relative' }}>
          <label className="field-label" htmlFor="logs-search" style={{ fontSize: '0.75rem' }}>
            Search notes
          </label>
          <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            <input
              id="logs-search"
              type="search"
              value={searchInput}
              onChange={(e) => setSearchInput(e.target.value)}
              placeholder="Search notes…"
              style={{ margin: '0.2rem 0 0', flex: 1 }}
            />
            {searchInput && (
              <button
                type="button"
                className="secondary"
                onClick={clearSearch}
                style={{ whiteSpace: 'nowrap' }}
              >
                Clear
              </button>
            )}
          </div>
        </div>

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

          {/* Habit filter with autocomplete (multi-select, AND logic) */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.3rem', position: 'relative' }}>
            <span className="field-label" style={{ fontSize: '0.75rem' }}>Habits</span>
            <input
              ref={habitInputRef}
              type="text"
              value={habitInput}
              onChange={(e) => {
                setHabitInput(e.target.value)
                setHabitAutocompleteOpen(true)
              }}
              onFocus={() => setHabitAutocompleteOpen(true)}
              onKeyDown={handleHabitKeyDown}
              placeholder="Add habit filter…"
              aria-label="Add habit filter"
              style={{
                width: '180px',
                padding: '0.4rem 0.55rem',
                fontSize: '0.85rem',
                margin: 0,
              }}
            />
            {filters.habits.length > 0 && (
              <div className="chip-row compact" style={{ maxWidth: '220px' }}>
                {filters.habits.map((habit) => (
                  <button
                    key={habit}
                    type="button"
                    className="chip"
                    onClick={() => removeHabit(habit)}
                    aria-label={`Remove habit filter ${habit}`}
                    style={{ cursor: 'pointer' }}
                  >
                    {habit} ×
                  </button>
                ))}
              </div>
            )}
            {habitAutocompleteOpen && (habitSuggestions.length > 0 || habitSuggestionsTruncated) && (
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
                  maxHeight: '200px',
                  overflowY: 'auto',
                  marginTop: '2px',
                }}
              >
                {habitSuggestions.map((habit) => (
                  <button
                    key={habit}
                    type="button"
                    onClick={() => addHabit(habit)}
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
                {habitSuggestionsTruncated && (
                  <div className="muted" style={{ padding: '0.4rem 0.65rem', fontSize: '0.75rem' }}>
                    (showing top {HABIT_SUGGESTION_LIMIT})
                  </div>
                )}
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
              aria-label="Filter from date"
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
              aria-label="Filter to date"
              style={{
                padding: '0.4rem 0.55rem',
                fontSize: '0.85rem',
                width: '140px',
                margin: 0,
              }}
            />
          </div>

          {/* Sort selector */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.3rem' }}>
            <label className="field-label" htmlFor="logs-sort" style={{ fontSize: '0.75rem' }}>
              Sort by
            </label>
            <select
              id="logs-sort"
              value={sort}
              onChange={(e) => handleSortChange(e.target.value as SortOption)}
              style={{
                padding: '0.4rem 0.55rem',
                fontSize: '0.85rem',
                width: '180px',
                borderRadius: '10px',
                border: '1px solid var(--line)',
                background: 'var(--surface)',
                color: 'var(--text)',
              }}
            >
              {SORT_OPTIONS.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
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
        {(hasFilters || hasSearch) && logsQuery.data && (
          <div style={{
            padding: '0.5rem 1.5rem',
            fontSize: '0.82rem',
            color: 'var(--muted)',
            borderBottom: '1px solid var(--line)',
          }}>
            Showing {displayedCount} of {totalCount} entries
          </div>
        )}

        {/* ── Selection / bulk actions toolbar ── */}
        {rows.length > 0 && (
          <div className="logs-selection-bar">
            <label className="logs-select-all">
              <input
                ref={selectAllRef}
                type="checkbox"
                checked={allSelectedOnPage}
                onChange={toggleSelectAll}
                aria-label="Select all on this page"
              />
              <span>Select all on this page</span>
            </label>
            {selectedIds.size > 0 && (
              <div className="logs-bulk-actions">
                <span className="muted">{selectedIds.size} selected</span>
                <button type="button" className="secondary" onClick={handleBulkExport}>
                  Export selected
                </button>
                <button
                  type="button"
                  className="danger"
                  onClick={() => {
                    deleteTriggerFocusRef.current = (document.activeElement as HTMLElement) ?? null
                    setIsDeleteDialogOpen(true)
                  }}
                >
                  Delete selected
                </button>
              </div>
            )}
          </div>
        )}

        <div className="list-stack">
          {rows.map((entry) => {
            const isSelected = selectedIds.has(entry.id)
            return (
              <div className={`log-row${isSelected ? ' selected' : ''}`} key={entry.id}>
                <label className="log-row-check" style={isSelected ? { opacity: 1 } : undefined}>
                  <input
                    type="checkbox"
                    checked={isSelected}
                    onChange={() => toggleSelect(entry.id)}
                    aria-label={`Select log from ${formatDate(entry.date)}`}
                  />
                </label>
                <Link
                  to={`/logs/${entry.id}`}
                  className="list-card log-row-card"
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

                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
                    {entry.image_path ? (
                      <LogImageThumbnail path={entry.image_path} alt="" size={40} />
                    ) : null}
                    <p className="muted note-preview" style={{ margin: 0 }}>
                      {renderNotePreview(entry.notes, debouncedSearch)}
                    </p>
                  </div>
                </Link>
              </div>
            )
          })}

          {logsQuery.isLoading || logsQuery.isFetching ? <div className="skeleton-line" /> : null}
          {!rows.length && !logsQuery.isLoading ? (
            hasSearch ? (
              <div
                className="muted"
                style={{
                  padding: '1rem 1.5rem',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '0.6rem',
                  alignItems: 'flex-start',
                }}
              >
                <span>No results for &ldquo;{debouncedSearch}&rdquo;</span>
                <button type="button" className="secondary" onClick={clearSearch}>
                  Clear search
                </button>
              </div>
            ) : (
              <p className="muted" style={{ padding: '1rem 1.5rem' }}>
                {hasFilters ? 'No entries match the current filters.' : 'No log entries yet.'}
              </p>
            )
          ) : null}
          {rows.length && page >= totalPages && !logsQuery.isFetching ? (
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

      {/* ── Bulk delete confirmation dialog ── */}
      {isDeleteDialogOpen && (
        <div className="modal-overlay" role="presentation" onClick={() => setIsDeleteDialogOpen(false)}>
          <div
            className="modal-card"
            role="dialog"
            aria-modal="true"
            aria-labelledby="bulk-delete-title"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 id="bulk-delete-title" style={{ margin: 0 }}>
              Delete {selectedIds.size} {selectedIds.size === 1 ? 'entry' : 'entries'}?
            </h3>
            <p className="muted" style={{ margin: 0 }}>
              This action cannot be undone. The selected log{' '}
              {selectedIds.size === 1 ? 'entry' : 'entries'} will be permanently removed.
            </p>
            <div className="modal-actions">
              <button
                ref={cancelDeleteRef}
                type="button"
                className="secondary"
                onClick={() => setIsDeleteDialogOpen(false)}
                disabled={bulkDeleteMutation.isPending}
              >
                Cancel
              </button>
              <button
                type="button"
                className="danger"
                onClick={() => bulkDeleteMutation.mutate([...selectedIds])}
                disabled={bulkDeleteMutation.isPending}
              >
                {bulkDeleteMutation.isPending
                  ? 'Deleting…'
                  : `Delete ${selectedIds.size} ${selectedIds.size === 1 ? 'entry' : 'entries'}`}
              </button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}
