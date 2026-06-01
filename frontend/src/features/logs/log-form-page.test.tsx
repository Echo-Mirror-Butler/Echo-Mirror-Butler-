import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { afterEach, beforeEach, describe, expect, test, vi } from 'vitest'
import { ToastProvider } from '../../lib/use-toast'
import { LogFormPage } from './log-form-page'

const insertMock = vi.fn()
const maybeSingleMock = vi.fn()
const singleMock = vi.fn()

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
    from: vi.fn(() => {
      const builder = {
        select: vi.fn(() => builder),
        eq: vi.fn(() => builder),
        gte: vi.fn(() => builder),
        lte: vi.fn(() => builder),
        insert: insertMock.mockImplementation(() => builder),
        update: vi.fn(() => builder),
        delete: vi.fn(() => builder),
        maybeSingle: maybeSingleMock,
        single: singleMock,
      }
      return builder
    }),
  },
}))

function renderCreateForm() {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  })

  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter initialEntries={['/logs/new']}>
        <ToastProvider>
          <Routes>
            <Route path='/logs/new' element={<LogFormPage mode='create' />} />
            <Route path='/logs' element={<h1>Logs list</h1>} />
          </Routes>
        </ToastProvider>
      </MemoryRouter>
    </QueryClientProvider>,
  )
}

describe('LogFormPage', () => {
  beforeEach(() => {
    insertMock.mockClear()
    maybeSingleMock.mockResolvedValue({ data: null, error: null })
    singleMock.mockResolvedValue({
      data: {
        id: 'created-log-id',
        user_id: 'test-user-id',
        date: new Date().toISOString(),
        mood: 3,
        habits: [],
        notes: 'Vitest create flow note',
      },
      error: null,
    })
  })

  afterEach(() => {
    vi.clearAllMocks()
  })

  test('shows an inline mood validation error when saving without a mood', async () => {
    const user = userEvent.setup()
    renderCreateForm()

    await user.click(screen.getByRole('button', { name: /save log entry/i }))

    expect(await screen.findByText('Mood score is required')).toBeInTheDocument()
    expect(insertMock).not.toHaveBeenCalled()
  })

  test('creates a log entry, shows a success toast, and redirects to logs', async () => {
    const user = userEvent.setup()
    renderCreateForm()

    await user.click(screen.getByRole('button', { name: 'Mood 3' }))
    await user.type(screen.getByPlaceholderText(/optional notes/i), 'Vitest create flow note')
    await user.click(screen.getByRole('button', { name: /save log entry/i }))

    await waitFor(() => expect(insertMock).toHaveBeenCalledTimes(1))
    expect(insertMock).toHaveBeenCalledWith(
      expect.objectContaining({
        user_id: 'test-user-id',
        mood: 3,
        habits: [],
        notes: 'Vitest create flow note',
      }),
    )
    expect(await screen.findByText('Mood logged! +1 ECHO earned 🎉')).toBeInTheDocument()
    expect(await screen.findByRole('heading', { name: /logs list/i })).toBeInTheDocument()
  })
})
