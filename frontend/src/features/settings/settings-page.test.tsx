import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router-dom'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { SettingsPage } from './settings-page'

const mockFrom = vi.hoisted(() => vi.fn())
const mockRpc = vi.hoisted(() => vi.fn())

vi.mock('../../lib/auth-context', () => ({
  useAuth: () => ({
    user: {
      id: 'test-user-id',
      email: 'test@example.com',
      user_metadata: {},
    },
    session: { access_token: 'mock-token' },
    isLoading: false,
    signOut: vi.fn(),
  }),
}))

vi.mock('../../lib/supabase', () => ({
  supabase: {
    from: mockFrom,
    rpc: mockRpc,
    auth: {
      updateUser: vi.fn().mockResolvedValue({ error: null }),
      signOut: vi.fn(),
    },
    storage: {
      from: vi.fn(() => ({
        upload: vi.fn().mockResolvedValue({ error: null }),
        getPublicUrl: vi.fn(() => ({ data: { publicUrl: 'http://example.com/avatar.jpg' } })),
      })),
    },
    functions: {
      invoke: vi.fn().mockResolvedValue({ data: {}, error: null }),
    },
  },
}))

vi.mock('../../lib/use-theme', () => ({
  useTheme: () => ({
    theme: 'light',
    setTheme: vi.fn(),
  }),
}))

vi.mock('../../lib/use-toast', () => ({
  useToast: () => ({
    showToast: vi.fn(),
  }),
}))

vi.mock('../notifications/notification-prefs', () => ({
  NotificationPrefs: () => <div data-testid="notification-prefs" />,
}))

function createMockChain(data: unknown = null, error: unknown = null) {
  const chain = {
    select: vi.fn(() => chain),
    eq: vi.fn(() => chain),
    single: vi.fn(() => Promise.resolve({ data, error })),
    upsert: vi.fn(() => Promise.resolve({ data: null, error })),
    update: vi.fn(() => chain),
  }
  return chain
}

function renderSettingsPage() {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  })

  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter initialEntries={['/settings']}>
        <SettingsPage />
      </MemoryRouter>
    </QueryClientProvider>,
  )
}

describe('SettingsPage', () => {
  beforeEach(() => {
    mockFrom.mockClear()
    mockRpc.mockClear()
  })

  it('renders profile section with user email', async () => {
    mockFrom.mockImplementation((table: string) => {
      if (table === 'profiles') {
        return createMockChain({
          display_name: 'Test User',
          avatar_url: null,
          timezone: 'America/New_York',
          leaderboard_anonymous: false,
        })
      }
      return createMockChain(null)
    })

    renderSettingsPage()

    await waitFor(() => {
      expect(screen.getByText('Profile')).toBeInTheDocument()
      expect(screen.getByDisplayValue('test@example.com')).toBeInTheDocument()
    })
  })

  it('renders theme section with theme buttons', async () => {
    mockFrom.mockImplementation(() => createMockChain(null))

    renderSettingsPage()

    await waitFor(() => {
      expect(screen.getByText('Theme')).toBeInTheDocument()
      expect(screen.getByRole('button', { name: /light/i })).toBeInTheDocument()
      expect(screen.getByRole('button', { name: /dark/i })).toBeInTheDocument()
      expect(screen.getByRole('button', { name: /system/i })).toBeInTheDocument()
    })
  })

  it('renders data export section', async () => {
    mockFrom.mockImplementation(() => createMockChain(null))

    renderSettingsPage()

    await waitFor(() => {
      expect(screen.getByText('Data export')).toBeInTheDocument()
      expect(screen.getByText('Export my data')).toBeInTheDocument()
    })
  })

  it('renders password change section', async () => {
    mockFrom.mockImplementation(() => createMockChain(null))

    renderSettingsPage()

    await waitFor(() => {
      expect(screen.getByText('Change password')).toBeInTheDocument()
      expect(screen.getByLabelText('New password')).toBeInTheDocument()
      expect(screen.getByLabelText('Confirm new password')).toBeInTheDocument()
    })
  })

  it('renders danger zone with delete account button', async () => {
    mockFrom.mockImplementation(() => createMockChain(null))

    renderSettingsPage()

    await waitFor(() => {
      expect(screen.getByText('Danger zone')).toBeInTheDocument()
      expect(screen.getByRole('button', { name: /delete account/i })).toBeInTheDocument()
    })
  })

  it('shows delete confirmation form when delete button clicked', async () => {
    mockFrom.mockImplementation(() => createMockChain(null))

    const user = userEvent.setup()
    renderSettingsPage()

    await waitFor(() => {
      expect(screen.getByRole('button', { name: /delete account/i })).toBeInTheDocument()
    })

    await user.click(screen.getByRole('button', { name: /delete account/i }))

    await waitFor(() => {
      expect(screen.getByText(/type your account email to confirm/i)).toBeInTheDocument()
      expect(screen.getByRole('button', { name: /schedule deletion/i })).toBeInTheDocument()
    })
  })

  it('shows error when email confirmation does not match', async () => {
    mockFrom.mockImplementation(() => createMockChain(null))

    const user = userEvent.setup()
    renderSettingsPage()

    await waitFor(() => {
      expect(screen.getByRole('button', { name: /delete account/i })).toBeInTheDocument()
    })

    await user.click(screen.getByRole('button', { name: /delete account/i }))

    await waitFor(() => {
      expect(screen.getByLabelText(/confirm account email for deletion/i)).toBeInTheDocument()
    })

    await user.type(screen.getByLabelText(/confirm account email for deletion/i), 'wrong@email.com')
    await user.click(screen.getByRole('button', { name: /schedule deletion/i }))

    await waitFor(() => {
      expect(screen.getByText(/email does not match/i)).toBeInTheDocument()
    })
  })

  it('renders notification preferences section', async () => {
    mockFrom.mockImplementation(() => createMockChain(null))

    renderSettingsPage()

    await waitFor(() => {
      expect(screen.getByTestId('notification-prefs')).toBeInTheDocument()
    })
  })

  it('displays display name from profile', async () => {
    mockFrom.mockImplementation((table: string) => {
      if (table === 'profiles') {
        return createMockChain({
          display_name: 'Jane Doe',
          avatar_url: null,
          timezone: 'UTC',
          leaderboard_anonymous: false,
        })
      }
      return createMockChain(null)
    })

    renderSettingsPage()

    await waitFor(() => {
      expect(screen.getByDisplayValue('Jane Doe')).toBeInTheDocument()
    })
  })
})
