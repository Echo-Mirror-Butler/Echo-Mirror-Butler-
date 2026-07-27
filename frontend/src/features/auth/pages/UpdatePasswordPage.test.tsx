import { render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { beforeEach, describe, expect, test, vi } from 'vitest'
import { UpdatePasswordPage } from './UpdatePasswordPage'

const mockGetSession = vi.fn()
const mockExchange = vi.fn()
const mockSignOut = vi.fn()
const mockOnAuthStateChange = vi.fn()

vi.mock('../../../lib/auth-context', () => ({
  useAuth: () => ({
    user: null,
    session: null,
    isLoading: false,
    signOut: vi.fn(),
  }),
}))

vi.mock('../../../lib/supabase', () => ({
  supabase: {
    auth: {
      getSession: (...args: unknown[]) => mockGetSession(...args),
      exchangeCodeForSession: (...args: unknown[]) => mockExchange(...args),
      signOut: (...args: unknown[]) => mockSignOut(...args),
      onAuthStateChange: (...args: unknown[]) => mockOnAuthStateChange(...args),
      updateUser: vi.fn(),
    },
  },
}))

function renderAt(path: string) {
  return render(
    <MemoryRouter initialEntries={[path]}>
      <Routes>
        <Route path="/update-password" element={<UpdatePasswordPage />} />
      </Routes>
    </MemoryRouter>,
  )
}

describe('UpdatePasswordPage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockSignOut.mockResolvedValue({ error: null })
    mockOnAuthStateChange.mockReturnValue({
      data: { subscription: { unsubscribe: vi.fn() } },
    })
    mockGetSession.mockResolvedValue({ data: { session: null }, error: null })
  })

  test('rejects tampered access_token query param without establishing session', async () => {
    renderAt('/update-password?access_token=stolen-token')

    await waitFor(() => {
      expect(screen.getByText(/invalid or expired reset link/i)).toBeInTheDocument()
    })
    expect(mockExchange).not.toHaveBeenCalled()
  })

  test('rejects missing session / code', async () => {
    renderAt('/update-password')

    await waitFor(
      () => {
        expect(screen.getByText(/invalid or expired reset link/i)).toBeInTheDocument()
      },
      { timeout: 2000 },
    )
  })

  test('exchanges PKCE code before enabling form', async () => {
    mockExchange.mockResolvedValue({
      data: { session: { user: { id: 'u1' } } },
      error: null,
    })

    renderAt('/update-password?code=recovery-code')

    await waitFor(() => {
      expect(mockSignOut).toHaveBeenCalledWith({ scope: 'local' })
      expect(mockExchange).toHaveBeenCalledWith('recovery-code')
      expect(screen.getByLabelText(/new password/i)).not.toBeDisabled()
    })
  })
})
