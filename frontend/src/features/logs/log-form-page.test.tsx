import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { afterEach, beforeEach, describe, expect, test, vi } from 'vitest'
import { ToastProvider } from '../../lib/use-toast'
import { LogFormPage } from './log-form-page'
import { supabase } from '../../lib/supabase'

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

  test('shows inline error when mood is not selected and form is submitted', async () => {
    const user = userEvent.setup()
    renderCreateForm()

    await user.type(screen.getByPlaceholderText(/optional notes/i), 'Test note without mood')
    await user.click(screen.getByRole('button', { name: /save log entry/i }))

    await waitFor(() => {
      expect(screen.getByText('Mood score is required')).toBeInTheDocument()
    })

    expect(insertMock).not.toHaveBeenCalled()
  })

  test('shows error when date validation fails on submit', async () => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2026-06-15T10:00:00.000Z'))

    const user = userEvent.setup({ delay: null })
    renderCreateForm()

    await user.click(screen.getByRole('button', { name: 'Mood 3' }))

    const dateInput = screen.getByLabelText(/date/i)
    await user.clear(dateInput)
    await user.type(dateInput, '2026-12-31')

    await user.click(screen.getByRole('button', { name: /save log entry/i }))

    await waitFor(
      () => {
        const errorElement = screen.queryByText(/Date cannot be in the future/i)
        expect(errorElement).toBeInTheDocument()
      },
      { timeout: 3000 },
    )

    expect(insertMock).not.toHaveBeenCalled()

    vi.useRealTimers()
  })

  test('habit chip renders with remove button and clicking removes the habit', async () => {
    const user = userEvent.setup()
    renderCreateForm()

    const exerciseChip = screen.getByRole('button', { name: 'Exercise' })
    await user.click(exerciseChip)

    await waitFor(() => {
      expect(screen.getByRole('button', { name: /Exercise ×/i })).toBeInTheDocument()
    })

    const removeButton = screen.getByRole('button', { name: /Exercise ×/i })
    await user.click(removeButton)

    await waitFor(() => {
      expect(screen.queryByRole('button', { name: /Exercise ×/i })).not.toBeInTheDocument()
    })
  })

  test('notes character counter displays character count', async () => {
    const user = userEvent.setup()
    renderCreateForm()

    const notesTextarea = screen.getByPlaceholderText(/optional notes/i)
    await user.type(notesTextarea, 'Hello world')

    await waitFor(() => {
      expect(screen.getByText(/11\/500/i)).toBeInTheDocument()
    })
  })

  test('mood emoji buttons have accessible aria-label', () => {
    renderCreateForm()

    expect(screen.getByRole('button', { name: 'Mood 1' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Mood 2' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Mood 3' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Mood 4' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Mood 5' })).toBeInTheDocument()
  })

  test('form inputs have associated label elements', () => {
    renderCreateForm()

    expect(screen.getByLabelText(/date/i)).toBeInTheDocument()
    expect(screen.getByLabelText(/notes/i)).toBeInTheDocument()
  })

  test('custom habit can be added via Enter key', async () => {
    const user = userEvent.setup()
    renderCreateForm()

    const habitInput = screen.getByPlaceholderText(/type a habit and press enter/i)
    await user.type(habitInput, 'Custom habit{Enter}')

    await waitFor(() => {
      expect(screen.getByText(/Custom habit ×/i)).toBeInTheDocument()
    })
  })

  test('max habits limit enforced at 5 habits', async () => {
    const user = userEvent.setup()
    renderCreateForm()

    await user.click(screen.getByRole('button', { name: 'Exercise' }))
    await user.click(screen.getByRole('button', { name: 'Meditation' }))
    await user.click(screen.getByRole('button', { name: 'Reading' }))
    await user.click(screen.getByRole('button', { name: 'Hydration' }))
    await user.click(screen.getByRole('button', { name: 'Sleep 8h' }))

    await waitFor(() => {
      expect(screen.getByText(/maximum 5 habits reached/i)).toBeInTheDocument()
    })
  })

  test('delete button triggers confirmation dialog', async () => {
    const deleteMock = vi.fn()
    const updateMock = vi.fn()

    const existingLogChain = {
      select: vi.fn(() => existingLogChain),
      eq: vi.fn(() => existingLogChain),
      maybeSingle: vi.fn(() =>
        Promise.resolve({
          data: {
            id: 'existing-log-id',
            user_id: 'test-user-id',
            date: '2024-04-29T12:00:00.000Z',
            mood: 4,
            habits: ['Exercise'],
            notes: 'Test note',
            created_at: '2024-04-29T12:00:00.000Z',
            updated_at: '2024-04-29T12:00:00.000Z',
          },
          error: null,
        }),
      ),
      update: updateMock.mockImplementation(() => existingLogChain),
      delete: deleteMock.mockImplementation(() => existingLogChain),
      single: vi.fn(() => Promise.resolve({ data: {}, error: null })),
    }

    vi.mocked(supabase.from).mockReturnValue(existingLogChain as any)

    const queryClient = new QueryClient({
      defaultOptions: {
        queries: { retry: false },
        mutations: { retry: false },
      },
    })

    const confirmSpy = vi.spyOn(window, 'confirm').mockReturnValue(true)

    render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter initialEntries={['/logs/existing-log-id/edit']}>
          <ToastProvider>
            <Routes>
              <Route path='/logs/:id/edit' element={<LogFormPage mode='edit' />} />
              <Route path='/logs' element={<h1>Logs list</h1>} />
            </Routes>
          </ToastProvider>
        </MemoryRouter>
      </QueryClientProvider>,
    )

    const user = userEvent.setup()

    await waitFor(() => {
      expect(screen.getByRole('button', { name: /delete entry/i })).toBeInTheDocument()
    })

    await user.click(screen.getByRole('button', { name: /delete entry/i }))

    expect(confirmSpy).toHaveBeenCalledWith('Delete this log entry? This cannot be undone.')

    confirmSpy.mockRestore()
  })
})
