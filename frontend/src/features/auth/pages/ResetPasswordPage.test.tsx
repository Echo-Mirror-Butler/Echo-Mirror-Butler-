import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, test, vi } from 'vitest'
import { ResetPasswordPage } from './ResetPasswordPage'

const mockInvoke = vi.fn()

vi.mock('../../../lib/supabase', () => ({
  supabase: {
    functions: {
      invoke: (...args: unknown[]) => mockInvoke(...args),
    },
    auth: {
      resetPasswordForEmail: vi.fn(),
    },
  },
}))

function renderPage() {
  return render(
    <MemoryRouter>
      <ResetPasswordPage />
    </MemoryRouter>,
  )
}

describe('ResetPasswordPage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  test('shows generic success on successful invoke', async () => {
    mockInvoke.mockResolvedValue({
      data: { success: true, message: 'ok' },
      error: null,
    })

    renderPage()
    fireEvent.change(screen.getByLabelText(/email/i), {
      target: { value: 'user@example.com' },
    })
    fireEvent.click(screen.getByRole('button', { name: /send reset link/i }))

    await waitFor(() => {
      expect(screen.getByText(/if an account exists for that email/i)).toBeInTheDocument()
    })
    expect(mockInvoke).toHaveBeenCalledWith(
      'request-password-reset',
      expect.objectContaining({
        body: expect.objectContaining({ email: 'user@example.com' }),
      }),
    )
  })

  test('surfaces rate limit errors without revealing email existence', async () => {
    mockInvoke.mockResolvedValue({
      data: {
        error: 'rate_limit_exceeded',
        message: 'Too many reset attempts. Please try again later.',
      },
      error: { message: 'Edge Function returned a non-2xx status code' },
    })

    renderPage()
    fireEvent.change(screen.getByLabelText(/email/i), {
      target: { value: 'spam@example.com' },
    })
    fireEvent.click(screen.getByRole('button', { name: /send reset link/i }))

    await waitFor(() => {
      expect(screen.getByText(/too many reset attempts/i)).toBeInTheDocument()
    })
    expect(
      screen.queryByText(/if an account exists for that email/i),
    ).not.toBeInTheDocument()
  })
})
