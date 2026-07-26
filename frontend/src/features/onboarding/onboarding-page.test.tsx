import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router-dom'
import { describe, it, expect, vi } from 'vitest'
import { OnboardingPage } from './onboarding-page'

const mockNavigate = vi.hoisted(() => vi.fn())

vi.mock('react-router-dom', async () => {
  const actual = await vi.importActual('react-router-dom')
  return {
    ...actual,
    useNavigate: () => mockNavigate,
  }
})

vi.mock('../../lib/auth-context', () => ({
  useAuth: () => ({
    user: {
      id: 'test-user-id',
      email: 'test@example.com',
    },
    session: null,
    isLoading: false,
    signOut: vi.fn(),
  }),
}))

vi.mock('../../lib/supabase', () => ({
  supabase: {
    from: vi.fn(() => ({
      insert: vi.fn().mockResolvedValue({ error: null }),
    })),
    auth: {
      updateUser: vi.fn().mockResolvedValue({ error: null }),
    },
  },
}))

function renderOnboardingPage() {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  })

  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter initialEntries={['/onboarding']}>
        <OnboardingPage />
      </MemoryRouter>
    </QueryClientProvider>,
  )
}

describe('OnboardingPage', () => {
  it('renders step 1 welcome screen', () => {
    renderOnboardingPage()

    expect(screen.getByText('Welcome to EchoMirror')).toBeInTheDocument()
    expect(screen.getByText(/your personal growth companion/i)).toBeInTheDocument()
    expect(screen.getByText('Step 1 of 4')).toBeInTheDocument()
  })

  it('shows three feature bullets on step 1', () => {
    renderOnboardingPage()

    expect(screen.getByText(/track your mood daily/i)).toBeInTheDocument()
    expect(screen.getByText(/get ai-powered insights/i)).toBeInTheDocument()
    expect(screen.getByText(/earn echo tokens/i)).toBeInTheDocument()
  })

  it('navigates to step 2 when "Get started" is clicked', async () => {
    const user = userEvent.setup()
    renderOnboardingPage()

    await user.click(screen.getByText('Get started'))

    await waitFor(() => {
      expect(screen.getByText('How are you feeling?')).toBeInTheDocument()
      expect(screen.getByText('Step 2 of 4')).toBeInTheDocument()
    })
  })

  it('skips to dashboard when "Skip for now" is clicked on step 1', async () => {
    const user = userEvent.setup()
    renderOnboardingPage()

    await user.click(screen.getByText('Skip for now'))

    await waitFor(() => {
      expect(mockNavigate).toHaveBeenCalledWith('/dashboard', { replace: true })
    })
  })

  it('navigates to step 3 after saving mood on step 2', async () => {
    const user = userEvent.setup()
    renderOnboardingPage()

    // Go to step 2
    await user.click(screen.getByText('Get started'))
    await waitFor(() => {
      expect(screen.getByText('How are you feeling?')).toBeInTheDocument()
    })

    // Save mood and go to step 3
    await user.click(screen.getByText('Next'))

    await waitFor(() => {
      expect(screen.getByText('Daily reminder')).toBeInTheDocument()
      expect(screen.getByText('Step 3 of 4')).toBeInTheDocument()
    })
  })

  it('navigates to step 4 completion screen after setting reminder', async () => {
    const user = userEvent.setup()
    renderOnboardingPage()

    // Step 1 -> Step 2
    await user.click(screen.getByText('Get started'))
    await waitFor(() => {
      expect(screen.getByText('How are you feeling?')).toBeInTheDocument()
    })

    // Step 2 -> Step 3
    await user.click(screen.getByText('Next'))
    await waitFor(() => {
      expect(screen.getByText('Daily reminder')).toBeInTheDocument()
    })

    // Step 3 -> Step 4
    await user.click(screen.getByText('Set reminder & finish'))

    await waitFor(() => {
      expect(screen.getByText("You're all set!")).toBeInTheDocument()
      expect(screen.getByText('Step 4 of 4')).toBeInTheDocument()
    })
  })

  it('skips to dashboard from step 2', async () => {
    const user = userEvent.setup()
    renderOnboardingPage()

    await user.click(screen.getByText('Get started'))
    await waitFor(() => {
      expect(screen.getByText('How are you feeling?')).toBeInTheDocument()
    })

    await user.click(screen.getByText('Skip'))

    await waitFor(() => {
      expect(mockNavigate).toHaveBeenCalledWith('/dashboard', { replace: true })
    })
  })

  it('shows Go to Dashboard button on step 4', async () => {
    const user = userEvent.setup()
    renderOnboardingPage()

    // Fast-track through steps
    await user.click(screen.getByText('Get started'))
    await waitFor(() => expect(screen.getByText('How are you feeling?')))
    await user.click(screen.getByText('Next'))
    await waitFor(() => expect(screen.getByText('Daily reminder')))
    await user.click(screen.getByText('Set reminder & finish'))

    await waitFor(() => {
      expect(screen.getByText('Go to Dashboard')).toBeInTheDocument()
    })
  })

  it('navigates to dashboard when Go to Dashboard is clicked on step 4', async () => {
    const user = userEvent.setup()
    renderOnboardingPage()

    // Fast-track through steps
    await user.click(screen.getByText('Get started'))
    await waitFor(() => expect(screen.getByText('How are you feeling?')))
    await user.click(screen.getByText('Next'))
    await waitFor(() => expect(screen.getByText('Daily reminder')))
    await user.click(screen.getByText('Set reminder & finish'))
    await waitFor(() => expect(screen.getByText('Go to Dashboard')))

    await user.click(screen.getByText('Go to Dashboard'))

    await waitFor(() => {
      expect(mockNavigate).toHaveBeenCalledWith('/dashboard', { replace: true })
    })
  })

  it('shows mood slider on step 2', async () => {
    const user = userEvent.setup()
    renderOnboardingPage()

    await user.click(screen.getByText('Get started'))

    await waitFor(() => {
      expect(screen.getByRole('slider')).toBeInTheDocument()
      expect(screen.getByText(/set your mood baseline/i)).toBeInTheDocument()
    })
  })
})
