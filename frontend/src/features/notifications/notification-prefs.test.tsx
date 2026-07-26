import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { NotificationPrefs } from './notification-prefs'

const mockFrom = vi.hoisted(() => vi.fn())

vi.mock('../../lib/supabase', () => ({
  supabase: {
    from: mockFrom,
  },
}))

vi.mock('../../lib/use-push-notifications', () => ({
  usePushNotifications: vi.fn(() => ({
    permissionState: 'default',
    prefs: { enabled: false, reminderTime: '09:00' },
    loading: false,
    error: null,
    swAvailable: true,
    subscriptionExpired: false,
    subscribe: vi.fn().mockResolvedValue(true),
    unsubscribe: vi.fn().mockResolvedValue(undefined),
    updateReminderTime: vi.fn().mockResolvedValue(undefined),
  })),
}))

vi.mock('../../lib/use-toast', () => ({
  useToast: () => ({
    showToast: vi.fn(),
  }),
}))

function createMockChain(data: unknown = null, error: unknown = null) {
  const chain = {
    select: vi.fn(() => chain),
    eq: vi.fn(() => chain),
    maybeSingle: vi.fn(() => Promise.resolve({ data, error })),
    update: vi.fn(() => chain),
  }
  return chain
}

function renderNotificationPrefs(userId = 'test-user-id') {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  })

  return render(
    <QueryClientProvider client={queryClient}>
      <NotificationPrefs userId={userId} />
    </QueryClientProvider>,
  )
}

describe('NotificationPrefs', () => {
  beforeEach(() => {
    mockFrom.mockClear()
  })

  it('renders daily mood reminders card', () => {
    mockFrom.mockImplementation(() => createMockChain(null))
    renderNotificationPrefs()

    expect(screen.getByText('Daily Mood Reminders')).toBeInTheDocument()
  })

  it('renders weekly mood report card', () => {
    mockFrom.mockImplementation(() => createMockChain(null))
    renderNotificationPrefs()

    expect(screen.getByText('Weekly Mood Report')).toBeInTheDocument()
  })

  it('shows reminder toggle as disabled by default', () => {
    mockFrom.mockImplementation(() => createMockChain(null))
    renderNotificationPrefs()

    const toggle = screen.getByRole('switch', { name: /enable daily reminders/i })
    expect(toggle).toHaveAttribute('aria-checked', 'false')
  })

  it('shows weekly digest toggle as disabled by default', async () => {
    mockFrom.mockImplementation((table: string) => {
      if (table === 'profiles') {
        return createMockChain({ weekly_digest: false })
      }
      return createMockChain(null)
    })

    renderNotificationPrefs()

    await waitFor(() => {
      const toggle = screen.getByRole('switch', { name: /enable weekly digest/i })
      expect(toggle).toHaveAttribute('aria-checked', 'false')
    })
  })

  it('enables push notification description text', () => {
    mockFrom.mockImplementation(() => createMockChain(null))
    renderNotificationPrefs()

    expect(screen.getByText(/enable to receive daily mood reminders/i)).toBeInTheDocument()
  })

  it('shows weekly digest description', async () => {
    mockFrom.mockImplementation((table: string) => {
      if (table === 'profiles') {
        return createMockChain({ weekly_digest: false })
      }
      return createMockChain(null)
    })

    renderNotificationPrefs()

    await waitFor(() => {
      expect(screen.getByText(/receive a weekly email every sunday evening/i)).toBeInTheDocument()
    })
  })

  it('toggles weekly digest on click', async () => {
    const mockUpdate = vi.fn(() => ({
      eq: vi.fn(() => Promise.resolve({ error: null })),
    }))
    mockFrom.mockImplementation((table: string) => {
      if (table === 'profiles') {
        const chain = {
          select: vi.fn(() => chain),
          eq: vi.fn(() => chain),
          maybeSingle: vi.fn(() => Promise.resolve({ data: { weekly_digest: false }, error: null })),
          update: vi.fn(() => mockUpdate),
        }
        return chain
      }
      return createMockChain(null)
    })

    const user = userEvent.setup()
    renderNotificationPrefs()

    await waitFor(() => {
      expect(screen.getByRole('switch', { name: /enable weekly digest/i })).toBeInTheDocument()
    })

    await user.click(screen.getByRole('switch', { name: /enable weekly digest/i }))

    await waitFor(() => {
      expect(mockUpdate).toHaveBeenCalled()
    })
  })
})
