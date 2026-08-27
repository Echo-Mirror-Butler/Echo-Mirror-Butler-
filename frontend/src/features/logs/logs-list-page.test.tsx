import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { afterEach, beforeEach, describe, expect, test, vi } from 'vitest'
import { ToastProvider } from '../../lib/use-toast'
import { LogsListPage } from './logs-list-page'
import type { LogEntry } from '../../lib/types'

// ── Mutable mock state, configured per test ──
let mockRows: LogEntry[] = []
let mockListCount = 0
let mockTotalCount = 0
let mockExportRows: LogEntry[] | null = null
let mockHabits: string[] = []

// Captured query-builder calls so tests can assert how the query was built.
const calls = {
  ilike: [] as [string, string][],
  contains: [] as [string, unknown][],
  order: [] as [string, unknown][],
  eq: [] as [string, unknown][],
  deleteIn: [] as string[][],
}

function makeEntry(overrides: Partial<LogEntry> = {}): LogEntry {
  return {
    id: 'log-1',
    user_id: 'test-user-id',
    date: '2026-06-01T12:00:00.000Z',
    mood: 4,
    habits: ['Exercise'],
    notes: 'Morning run felt good',
    image_path: null,
    created_at: '2026-06-01T13:00:00.000Z',
    updated_at: '2026-06-01T13:00:00.000Z',
    ...overrides,
  }
}

vi.mock('../../lib/auth-context', () => ({
  useAuth: () => ({
    user: { id: 'test-user-id', email: 'test@example.com' },
    session: null,
    isLoading: false,
    signOut: vi.fn(),
  }),
}))

vi.mock('../../lib/supabase', () => {
  const makeBuilder = () => {
    let head = false
    let isDelete = false
    const builder: Record<string, unknown> = {
      select: vi.fn((_cols: string, opts?: { head?: boolean }) => {
        if (opts?.head) head = true
        return builder
      }),
      eq: vi.fn((col: string, val: unknown) => {
        calls.eq.push([col, val])
        return builder
      }),
      not: vi.fn(() => builder),
      gte: vi.fn(() => builder),
      lte: vi.fn(() => builder),
      ilike: vi.fn((col: string, val: string) => {
        calls.ilike.push([col, val])
        return builder
      }),
      contains: vi.fn((col: string, val: unknown) => {
        calls.contains.push([col, val])
        return builder
      }),
      order: vi.fn((col: string, opts?: unknown) => {
        calls.order.push([col, opts])
        return builder
      }),
      delete: vi.fn(() => {
        isDelete = true
        return builder
      }),
      in: vi.fn((_col: string, vals: string[]) => {
        if (isDelete) calls.deleteIn.push(vals)
        return builder
      }),
      maybeSingle: vi.fn(() => Promise.resolve({ data: null, error: null })),
      range: vi.fn(() =>
        Promise.resolve({ data: mockRows, count: mockListCount, error: null }),
      ),
      // Make the builder awaitable for queries that have no `.range()` terminal.
      then: (onFulfilled: (value: unknown) => unknown, onRejected?: (reason: unknown) => unknown) => {
        let value: unknown
        if (isDelete) value = { error: null }
        else if (head) value = { count: mockTotalCount, error: null }
        else value = { data: mockExportRows ?? mockRows, error: null }
        return Promise.resolve(value).then(onFulfilled, onRejected)
      },
    }
    return builder
  }

  return {
    supabase: {
      from: vi.fn(() => makeBuilder()),
      rpc: vi.fn(() => Promise.resolve({ data: mockHabits, error: null })),
    },
  }
})

function renderPage() {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  })

  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter initialEntries={['/logs']}>
        <ToastProvider>
          <Routes>
            <Route path="/logs" element={<LogsListPage />} />
          </Routes>
        </ToastProvider>
      </MemoryRouter>
    </QueryClientProvider>,
  )
}

beforeEach(() => {
  mockRows = [makeEntry()]
  mockListCount = 1
  mockTotalCount = 1
  mockExportRows = null
  mockHabits = []
  calls.ilike = []
  calls.contains = []
  calls.order = []
  calls.eq = []
  calls.deleteIn = []
  sessionStorage.clear()
  // jsdom does not implement object URLs.
  URL.createObjectURL = vi.fn(() => 'blob:mock')
  URL.revokeObjectURL = vi.fn()
})

afterEach(() => {
  vi.clearAllMocks()
})

describe('LogsListPage — search', () => {
  test('debounces input and runs an ILIKE query on notes', async () => {
    const user = userEvent.setup()
    renderPage()

    await screen.findByText('Jun 1, 2026')

    await user.type(screen.getByPlaceholderText(/search notes/i), 'run')

    await waitFor(
      () => expect(calls.ilike).toContainEqual(['notes', '%run%']),
      { timeout: 2000 },
    )
  })

  test('highlights the matched term in the notes preview', async () => {
    const user = userEvent.setup()
    const { container } = renderPage()

    await screen.findByText('Jun 1, 2026')
    await user.type(screen.getByPlaceholderText(/search notes/i), 'run')

    await waitFor(
      () => {
        const mark = container.querySelector('mark')
        expect(mark).not.toBeNull()
        expect(mark?.textContent?.toLowerCase()).toBe('run')
      },
      { timeout: 2000 },
    )
  })

  test('shows a "No results" empty state with a clear button', async () => {
    const user = userEvent.setup()
    renderPage()

    await screen.findByText('Jun 1, 2026')

    // After the search debounce, the query returns no rows.
    mockRows = []
    mockListCount = 0
    await user.type(screen.getByPlaceholderText(/search notes/i), 'zzz')

    const emptyState = await screen.findByText(/No results for/i, {}, { timeout: 2000 })
    expect(emptyState.textContent).toContain('zzz')

    mockRows = [makeEntry()]
    mockListCount = 1
    await user.click(screen.getByRole('button', { name: /clear search/i }))

    await waitFor(() => expect(screen.queryByText(/No results for/i)).not.toBeInTheDocument())
  })
})

describe('LogsListPage — sorting', () => {
  test('persists the sort preference in sessionStorage and reorders the query', async () => {
    const user = userEvent.setup()
    renderPage()

    await screen.findByText('Jun 1, 2026')

    await user.selectOptions(screen.getByLabelText(/sort by/i), 'mood_desc')

    await waitFor(() => {
      expect(sessionStorage.getItem('echomirror:logs-sort')).toBe('mood_desc')
      expect(calls.order.some(([col]) => col === 'mood')).toBe(true)
    })
  })

  test('restores the persisted sort on mount', async () => {
    sessionStorage.setItem('echomirror:logs-sort', 'mood_asc')
    renderPage()

    const select = (await screen.findByLabelText(/sort by/i)) as HTMLSelectElement
    expect(select.value).toBe('mood_asc')
  })
})

describe('LogsListPage — habit filter', () => {
  test('filters by multiple habits with AND logic', async () => {
    mockHabits = ['Exercise', 'Reading', 'Sleep']
    const user = userEvent.setup()
    renderPage()

    await screen.findByText('Jun 1, 2026')

    await user.click(screen.getByLabelText(/add habit filter/i))
    await user.click(await screen.findByRole('button', { name: 'Reading' }))

    await waitFor(() => expect(calls.contains).toContainEqual(['habits', ['Reading']]))

    await user.click(screen.getByLabelText(/add habit filter/i))
    await user.click(await screen.findByRole('button', { name: 'Exercise' }))

    await waitFor(() => {
      const containsHabits = calls.contains.filter(([col]) => col === 'habits')
      const last = containsHabits[containsHabits.length - 1]
      expect(last[1]).toEqual(['Reading', 'Exercise'])
    })
  })

  test('shows a "(showing top 20)" label when suggestions are truncated', async () => {
    mockHabits = Array.from({ length: 25 }, (_, i) => `Habit${String(i + 1).padStart(2, '0')}`)
    const user = userEvent.setup()
    renderPage()

    await screen.findByText('Jun 1, 2026')
    await user.click(screen.getByLabelText(/add habit filter/i))

    expect(await screen.findByText(/showing top 20/i)).toBeInTheDocument()
  })
})

describe('LogsListPage — bulk actions', () => {
  test('bulk delete confirms the count and deletes the selected ids', async () => {
    mockRows = [makeEntry({ id: 'log-1' }), makeEntry({ id: 'log-2', date: '2026-06-02T12:00:00.000Z' })]
    mockListCount = 2
    mockTotalCount = 2
    const user = userEvent.setup()
    renderPage()

    await screen.findByText('Jun 1, 2026')

    await user.click(screen.getByLabelText(/select all on this page/i))
    expect(await screen.findByText('2 selected')).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: /delete selected/i }))

    const dialog = await screen.findByRole('dialog')
    expect(within(dialog).getByText(/Delete 2 entries\?/i)).toBeInTheDocument()

    await user.click(within(dialog).getByRole('button', { name: 'Delete 2 entries' }))

    await waitFor(() => {
      expect(calls.deleteIn).toHaveLength(1)
      expect(calls.deleteIn[0]).toEqual(expect.arrayContaining(['log-1', 'log-2']))
    })

    expect(await screen.findByText('2 entries deleted')).toBeInTheDocument()
  })

  test('bulk export builds a CSV of the selected entries', async () => {
    mockRows = [
      makeEntry({ id: 'log-1', notes: 'first' }),
      makeEntry({ id: 'log-2', notes: 'second', date: '2026-06-02T12:00:00.000Z' }),
    ]
    mockListCount = 2
    mockTotalCount = 2

    let capturedBlob: Blob | null = null
    URL.createObjectURL = vi.fn((blob: Blob) => {
      capturedBlob = blob
      return 'blob:mock'
    }) as unknown as typeof URL.createObjectURL

    const user = userEvent.setup()
    renderPage()

    await screen.findByText('Jun 1, 2026')

    await user.click(screen.getByLabelText(/select all on this page/i))
    await user.click(screen.getByRole('button', { name: /export selected/i }))

    await waitFor(() => expect(capturedBlob).not.toBeNull())
    const text = await (capturedBlob as unknown as Blob).text()
    const lines = text.split('\n')
    expect(lines[0]).toBe('id,date,mood,habits,notes,created_at')
    expect(lines).toHaveLength(3)
    expect(text).toContain('log-1')
    expect(text).toContain('log-2')
  })

  test('closes the delete dialog when Escape is pressed', async () => {
    const user = userEvent.setup()
    renderPage()

    await screen.findByText('Jun 1, 2026')

    await user.click(screen.getByLabelText(/select all on this page/i))
    await user.click(screen.getByRole('button', { name: /delete selected/i }))

    expect(await screen.findByRole('dialog')).toBeInTheDocument()

    fireEvent.keyDown(window, { key: 'Escape' })

    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
  })

  test('toggles a single row selection via its checkbox', async () => {
    renderPage()

    await screen.findByText('Jun 1, 2026')

    const rowCheckbox = screen.getByLabelText(/select log from jun 1, 2026/i)
    fireEvent.click(rowCheckbox)

    expect(await screen.findByText('1 selected')).toBeInTheDocument()
  })
})

describe('LogsListPage — CSV export header', () => {
  test('full export includes the id column and a header row', async () => {
    mockExportRows = [makeEntry({ id: 'log-9', notes: 'exported' })]

    let capturedBlob: Blob | null = null
    URL.createObjectURL = vi.fn((blob: Blob) => {
      capturedBlob = blob
      return 'blob:mock'
    }) as unknown as typeof URL.createObjectURL

    const user = userEvent.setup()
    renderPage()

    await screen.findByText('Jun 1, 2026')
    await user.click(screen.getByRole('button', { name: /export csv/i }))

    await waitFor(() => expect(capturedBlob).not.toBeNull())
    const text = await (capturedBlob as unknown as Blob).text()
    expect(text.split('\n')[0]).toBe('id,date,mood,habits,notes,created_at')
    expect(text).toContain('log-9')
  })
})
