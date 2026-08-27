import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { afterEach, beforeEach, describe, expect, test, vi } from 'vitest'
import { DashboardPage } from './dashboard-page'

const mockFrom = vi.hoisted(() => vi.fn())
const mockRpc = vi.hoisted(() => vi.fn())

vi.mock('../../lib/auth-context', () => ({
  useAuth: () => ({
    user: {
      id: 'test-user-id',
      email: 'test@example.com',
      user_metadata: { onboarding_completed: true },
    },
    session: null,
    isLoading: false,
    signOut: vi.fn(),
  }),
}))

vi.mock('../../lib/supabase', () => ({
  supabase: {
    from: mockFrom,
    rpc: mockRpc,
  },
}))

vi.mock('../../features/dashboard/components/habit-tracker-widget', () => ({
  HabitTrackerWidget: () => {
    return (
      <article className="card">
        <div className="card-header">
          <h3>Habit Tracker</h3>
        </div>
      </article>
    )
  },
}))

function createMockChain(data: unknown = null, error: unknown = null) {
  const chain = {
    selectedFields: '',
    select: vi.fn((fields) => {
      chain.selectedFields = fields || ''
      return chain
    }),
    eq: vi.fn(() => chain),
    gte: vi.fn(() => chain),
    lt: vi.fn(() => chain),
    lte: vi.fn(() => chain),
    order: vi.fn(() => chain),
    limit: vi.fn(() => chain),
    maybeSingle: vi.fn(() => Promise.resolve({ data, error })),
    single: vi.fn(() => Promise.resolve({ data, error })),
    then: vi.fn((onFulfilled) => {
      if (chain.selectedFields.includes('notes')) {
        const resultData = data !== null ? data : [{ id: 'mock-recent-log', mood: 4, date: '2024-04-26' }]
        return Promise.resolve({ data: resultData, error: null }).then(onFulfilled)
      }
      return chain.maybeSingle().then(onFulfilled)
    }),
  }
  return chain
}

function renderDashboardPage() {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  })

  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter initialEntries={['/dashboard']}>
        <Routes>
          <Route path="/dashboard" element={<DashboardPage />} />
          <Route path="/wallet" element={<div>Wallet Page</div>} />
          <Route path="/logs" element={<div>Logs Page</div>} />
          <Route path="/log" element={<div>Log Page</div>} />
          <Route path="/logs/new" element={<div>New Log Page</div>} />
          <Route path="/logs/:id/edit" element={<div>Edit Log Page</div>} />
          <Route path="/insights" element={<div>Insights Page</div>} />
        </Routes>
      </MemoryRouter>
    </QueryClientProvider>,
  )
}

describe('DashboardPage', () => {
  beforeEach(() => {
    mockFrom.mockClear()
    mockRpc.mockClear()
  })

  afterEach(() => {
    vi.clearAllMocks()
  })

  test('renders all 7 widget headings', async () => {
    mockRpc.mockResolvedValue({ data: 5, error: null })

    const logsChain = createMockChain([{ id: 'mock-log-id', date: '2026-07-27', mood: 4 }])
    const insightChain = createMockChain(null)
    const walletChain = createMockChain({ balance: 10 })
    const rewardsChain = createMockChain([])
    const moodTrendChain = createMockChain([])

    mockFrom.mockImplementation((table: string) => {
      if (table === 'log_entries') {
        return logsChain
      }
      if (table === 'ai_insights') {
        return insightChain
      }
      if (table === 'user_wallets') {
        return walletChain
      }
      if (table === 'echo_rewards') {
        return rewardsChain
      }
      return moodTrendChain
    })

    renderDashboardPage()

    await waitFor(() => {
      expect(screen.getByText(/How are you feeling today\?/i)).toBeInTheDocument()
      expect(screen.getByText('Mood Summary')).toBeInTheDocument()
      expect(screen.getByText('Streak')).toBeInTheDocument()
      expect(screen.getByText('ECHO Balance')).toBeInTheDocument()
      expect(screen.getByText('Habit Tracker')).toBeInTheDocument()
      expect(screen.getByText('Recent Logs')).toBeInTheDocument()
      expect(screen.getByText('Latest Insight')).toBeInTheDocument()
    })
  })

  test('empty state renders on zero logs', async () => {
    mockRpc.mockResolvedValue({ data: 0, error: null })

    const logsChain = createMockChain([])
    logsChain.limit = vi.fn(() => logsChain)
    const insightChain = createMockChain(null)
    const walletChain = createMockChain({ balance: 10 })
    const rewardsChain = createMockChain([])

    mockFrom.mockImplementation((table: string) => {
      if (table === 'log_entries') {
        return logsChain
      }
      if (table === 'ai_insights') {
        return insightChain
      }
      if (table === 'user_wallets') {
        return walletChain
      }
      if (table === 'echo_rewards') {
        return rewardsChain
      }
      return createMockChain([])
    })

    renderDashboardPage()

    await waitFor(() => {
      expect(screen.getByText('Your mirror is empty')).toBeInTheDocument()
      expect(screen.getByText('Log your first mood to start your streak.')).toBeInTheDocument()
    })
  })

  test('mood trend card shows percentage badge based on mock data', async () => {
    mockRpc.mockResolvedValue({ data: 5, error: null })

    const thisWeekData = [
      {
        id: 'log-1',
        user_id: 'test-user-id',
        date: '2024-04-26T10:00:00.000Z',
        mood: 4,
        notes: null,
        habits: [],
      },
      {
        id: 'log-2',
        user_id: 'test-user-id',
        date: '2024-04-27T10:00:00.000Z',
        mood: 5,
        notes: null,
        habits: [],
      },
    ]

    const prevWeekData = [
      {
        id: 'log-3',
        user_id: 'test-user-id',
        date: '2024-04-20T10:00:00.000Z',
        mood: 3,
        notes: null,
        habits: [],
      },
    ]

    let callCount = 0
    const logsChain = createMockChain()
    logsChain.order = vi.fn(() => logsChain)

    logsChain.maybeSingle = vi.fn(() => {
      callCount++
      if (callCount === 1) {
        return Promise.resolve({ data: thisWeekData, error: null })
      }
      if (callCount === 2) {
        return Promise.resolve({ data: prevWeekData, error: null })
      }
      return Promise.resolve({ data: [], error: null })
    })

    const insightChain = createMockChain(null)
    const walletChain = createMockChain({ balance: 10 })
    const rewardsChain = createMockChain([])

    mockFrom.mockImplementation((table: string) => {
      if (table === 'log_entries') {
        const queryChain = createMockChain()
        queryChain.maybeSingle = vi.fn(() => logsChain.maybeSingle())
        return queryChain
      }
      if (table === 'ai_insights') {
        return insightChain
      }
      if (table === 'user_wallets') {
        return walletChain
      }
      if (table === 'echo_rewards') {
        return rewardsChain
      }
      return createMockChain([])
    })

    renderDashboardPage()

    await waitFor(() => {
      expect(screen.getByText(/vs last week/i)).toBeInTheDocument()
      expect(screen.getByText(/4\.5 \/ 5/i)).toBeInTheDocument()
    })
  })

  test('clicking ECHO balance card navigates to wallet page', async () => {
    mockRpc.mockResolvedValue({ data: 5, error: null })

    const logsChain = createMockChain([{ id: 'mock-log-id', date: '2026-07-27', mood: 4 }])
    const insightChain = createMockChain(null)
    const walletChain = createMockChain({ balance: 50 })
    const rewardsChain = createMockChain([])

    mockFrom.mockImplementation((table: string) => {
      if (table === 'log_entries') {
        return logsChain
      }
      if (table === 'ai_insights') {
        return insightChain
      }
      if (table === 'user_wallets') {
        return walletChain
      }
      if (table === 'echo_rewards') {
        return rewardsChain
      }
      return createMockChain([])
    })

    const user = userEvent.setup()
    renderDashboardPage()

    await waitFor(() => {
      expect(screen.getByText('50 ECHO', { exact: false })).toBeInTheDocument()
    })

    const echoCard = screen.getByText('ECHO Balance').closest('article')
    expect(echoCard).toBeInTheDocument()

    await user.click(echoCard!)

    await waitFor(() => {
      expect(screen.getByText('Wallet Page')).toBeInTheDocument()
    })
  })

  test('CTA banner Log Todays Mood navigates to new log page', async () => {
    mockRpc.mockResolvedValue({ data: 0, error: null })

    const logsChain = createMockChain([{ id: 'mock-log-id', date: '2026-07-27', mood: 4 }])
    logsChain.maybeSingle = vi.fn(() => Promise.resolve({ data: null, error: null }))

    const insightChain = createMockChain(null)
    const walletChain = createMockChain({ balance: 10 })
    const rewardsChain = createMockChain([])

    mockFrom.mockImplementation((table: string) => {
      if (table === 'log_entries') {
        return logsChain
      }
      if (table === 'ai_insights') {
        return insightChain
      }
      if (table === 'user_wallets') {
        return walletChain
      }
      if (table === 'echo_rewards') {
        return rewardsChain
      }
      return createMockChain([])
    })

    const user = userEvent.setup()
    renderDashboardPage()

    await waitFor(() => {
      expect(screen.getByText("Log Today's Mood")).toBeInTheDocument()
    })

    await user.click(screen.getByText("Log Today's Mood"))

    await waitFor(() => {
      expect(screen.getByText('New Log Page')).toBeInTheDocument()
    })
  })

  test('recent logs list shows log entries with mood emoji', async () => {
    mockRpc.mockResolvedValue({ data: 3, error: null })

    const logsData = [
      {
        id: 'log-1',
        user_id: 'test-user-id',
        date: '2024-04-29T10:00:00.000Z',
        mood: 5,
        notes: 'Feeling great today',
        habits: [],
        created_at: '2024-04-29T10:00:00.000Z',
        updated_at: '2024-04-29T10:00:00.000Z',
      },
      {
        id: 'log-2',
        user_id: 'test-user-id',
        date: '2024-04-28T10:00:00.000Z',
        mood: 3,
        notes: null,
        habits: [],
        created_at: '2024-04-28T10:00:00.000Z',
        updated_at: '2024-04-28T10:00:00.000Z',
      },
    ]

    const logsChain = createMockChain(logsData)
    logsChain.limit = vi.fn(() => logsChain)

    const insightChain = createMockChain(null)
    const walletChain = createMockChain({ balance: 10 })
    const rewardsChain = createMockChain([])

    mockFrom.mockImplementation((table: string) => {
      if (table === 'log_entries') {
        return logsChain
      }
      if (table === 'ai_insights') {
        return insightChain
      }
      if (table === 'user_wallets') {
        return walletChain
      }
      if (table === 'echo_rewards') {
        return rewardsChain
      }
      return createMockChain([])
    })

    renderDashboardPage()

    await waitFor(() => {
      expect(screen.getByText(/Feeling great today/i)).toBeInTheDocument()
      expect(screen.getByText(/No notes/i)).toBeInTheDocument()
    })
  })

  test('streak card shows current streak when available', async () => {
    mockRpc.mockResolvedValue({ data: 7, error: null })

    const logsChain = createMockChain([{ id: 'mock-log-id', date: '2026-07-27', mood: 4 }])
    const insightChain = createMockChain(null)
    const walletChain = createMockChain({ balance: 10 })
    const rewardsChain = createMockChain([])

    mockFrom.mockImplementation((table: string) => {
      if (table === 'log_entries') {
        return logsChain
      }
      if (table === 'ai_insights') {
        return insightChain
      }
      if (table === 'user_wallets') {
        return walletChain
      }
      if (table === 'echo_rewards') {
        return rewardsChain
      }
      return createMockChain([])
    })

    renderDashboardPage()

    await waitFor(() => {
      expect(screen.getByText('7-day streak', { exact: false })).toBeInTheDocument()
    })
  })

  test('insight preview shows truncated text with view more button', async () => {
    mockRpc.mockResolvedValue({ data: 0, error: null })

    const logsChain = createMockChain([{ id: 'mock-log-id', date: '2026-07-27', mood: 4 }])
    const insightData = {
      id: 'insight-1',
      user_id: 'test-user-id',
      prediction:
        'Based on your recent mood patterns, you seem to be experiencing a positive trend. Your mood has been consistently above average for the past week.',
      suggestions: [],
      future_letter: '',
      stress_level: 2,
      created_at: '2024-04-29T10:00:00.000Z',
    }
    const insightChain = createMockChain(insightData)
    const walletChain = createMockChain({ balance: 10 })
    const rewardsChain = createMockChain([])

    mockFrom.mockImplementation((table: string) => {
      if (table === 'log_entries') {
        return logsChain
      }
      if (table === 'ai_insights') {
        return insightChain
      }
      if (table === 'user_wallets') {
        return walletChain
      }
      if (table === 'echo_rewards') {
        return rewardsChain
      }
      return createMockChain([])
    })

    const user = userEvent.setup()
    renderDashboardPage()

    await waitFor(() => {
      expect(
        screen.getByText(/Based on your recent mood patterns/i, { exact: false }),
      ).toBeInTheDocument()
      expect(screen.getByText('View full analysis →')).toBeInTheDocument()
    })

    await user.click(screen.getByText('View full analysis →'))

    await waitFor(() => {
      expect(screen.getByText('Insights Page')).toBeInTheDocument()
    })
  })

  test('all interactive elements have accessible labels', async () => {
    mockRpc.mockResolvedValue({ data: 0, error: null })

    const logsChain = createMockChain([{ id: 'mock-log-id', date: '2026-07-27', mood: 4 }])
    const insightChain = createMockChain(null)
    const walletChain = createMockChain({ balance: 10 })
    const rewardsChain = createMockChain([])

    mockFrom.mockImplementation((table: string) => {
      if (table === 'log_entries') {
        return logsChain
      }
      if (table === 'ai_insights') {
        return insightChain
      }
      if (table === 'user_wallets') {
        return walletChain
      }
      if (table === 'echo_rewards') {
        return rewardsChain
      }
      return createMockChain([])
    })

    renderDashboardPage()

    await waitFor(() => {
      expect(screen.getByRole('button', { name: "Log Today's Mood" })).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'View all' })).toBeInTheDocument()
    })
  })

  test('empty state CTA button navigates to /log', async () => {
    mockRpc.mockResolvedValue({ data: 0, error: null })

    const logsChain = createMockChain([])
    const insightChain = createMockChain(null)
    const walletChain = createMockChain({ balance: 10 })
    const rewardsChain = createMockChain([])

    mockFrom.mockImplementation((table: string) => {
      if (table === 'log_entries') {
        return logsChain
      }
      if (table === 'ai_insights') {
        return insightChain
      }
      if (table === 'user_wallets') {
        return walletChain
      }
      if (table === 'echo_rewards') {
        return rewardsChain
      }
      return createMockChain([])
    })

    const user = userEvent.setup()
    renderDashboardPage()

    await waitFor(() => {
      expect(screen.getByRole('button', { name: 'Log your first mood' })).toBeInTheDocument()
    })

    await user.click(screen.getByRole('button', { name: 'Log your first mood' }))

    await waitFor(() => {
      expect(screen.getByText('Log Page')).toBeInTheDocument()
    })
  })

  test('empty state is hidden once logs exist', async () => {
    mockRpc.mockResolvedValue({ data: 5, error: null })

    const logsChain = createMockChain([{ id: 'log-1', date: '2026-07-27', mood: 4 }])
    const insightChain = createMockChain(null)
    const walletChain = createMockChain({ balance: 10 })
    const rewardsChain = createMockChain([])

    mockFrom.mockImplementation((table: string) => {
      if (table === 'log_entries') {
        return logsChain
      }
      if (table === 'ai_insights') {
        return insightChain
      }
      if (table === 'user_wallets') {
        return walletChain
      }
      if (table === 'echo_rewards') {
        return rewardsChain
      }
      return createMockChain([])
    })

    renderDashboardPage()

    await waitFor(() => {
      expect(screen.queryByText('Your mirror is empty')).not.toBeInTheDocument()
      expect(screen.getByText('Mood Summary')).toBeInTheDocument()
    })
  })
})
