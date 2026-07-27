import { render, waitFor } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { beforeEach, describe, expect, test, vi } from 'vitest'
import { AuthCallbackPage } from './AuthCallbackPage'

const mockNavigate = vi.fn()
const mockExchange = vi.fn()
const mockSignOut = vi.fn()

vi.mock('react-router-dom', async () => {
  const actual = await vi.importActual<typeof import('react-router-dom')>('react-router-dom')
  return {
    ...actual,
    useNavigate: () => mockNavigate,
  }
})

vi.mock('../../../lib/supabase', () => ({
  supabase: {
    auth: {
      exchangeCodeForSession: (...args: unknown[]) => mockExchange(...args),
      signOut: (...args: unknown[]) => mockSignOut(...args),
    },
  },
}))

function renderAt(path: string) {
  return render(
    <MemoryRouter initialEntries={[path]}>
      <Routes>
        <Route path="/auth/callback" element={<AuthCallbackPage />} />
      </Routes>
    </MemoryRouter>,
  )
}

describe('AuthCallbackPage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockSignOut.mockResolvedValue({ error: null })
  })

  test('rejects missing code param (tampered/incomplete callback)', async () => {
    renderAt('/auth/callback')
    await waitFor(() => {
      expect(mockNavigate).toHaveBeenCalledWith('/login?error=missing_code', {
        replace: true,
      })
    })
    expect(mockExchange).not.toHaveBeenCalled()
  })

  test('rejects provider error query params', async () => {
    renderAt('/auth/callback?error=access_denied')
    await waitFor(() => {
      expect(mockNavigate).toHaveBeenCalledWith(
        expect.stringContaining('/login?error='),
        { replace: true },
      )
    })
    expect(mockExchange).not.toHaveBeenCalled()
  })

  test('signs out locally then exchanges code on success', async () => {
    mockExchange.mockResolvedValue({
      data: {
        session: {
          user: { id: 'u1', user_metadata: { onboarding_completed: true } },
        },
      },
      error: null,
    })

    renderAt('/auth/callback?code=valid-pkce-code')

    await waitFor(() => {
      expect(mockSignOut).toHaveBeenCalledWith({ scope: 'local' })
      expect(mockExchange).toHaveBeenCalledWith('valid-pkce-code')
      expect(mockNavigate).toHaveBeenCalledWith('/dashboard', { replace: true })
    })
  })

  test('navigates to login when exchange fails', async () => {
    mockExchange.mockResolvedValue({
      data: { session: null },
      error: { message: 'invalid code verifier' },
    })

    renderAt('/auth/callback?code=tampered')

    await waitFor(() => {
      expect(mockNavigate).toHaveBeenCalledWith('/login?error=oauth_failed', {
        replace: true,
      })
    })
  })

  test('routes to onboarding when not completed', async () => {
    mockExchange.mockResolvedValue({
      data: {
        session: {
          user: { id: 'u1', user_metadata: {} },
        },
      },
      error: null,
    })

    renderAt('/auth/callback?code=ok')

    await waitFor(() => {
      expect(mockNavigate).toHaveBeenCalledWith('/onboarding', { replace: true })
    })
  })
})
