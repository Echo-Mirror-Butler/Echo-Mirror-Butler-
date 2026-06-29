import { render, act } from '@testing-library/react'
import { screen, waitFor } from '@testing-library/dom'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { AuthProvider, useAuth } from './auth-context'
import type { Session, User } from '@supabase/supabase-js'

const { mockGetSession, mockOnAuthStateChange, mockSignOut } = vi.hoisted(() => ({
  mockGetSession: vi.fn(),
  mockOnAuthStateChange: vi.fn(),
  mockSignOut: vi.fn(),
}))

vi.mock('./supabase', () => ({
  supabase: {
    auth: {
      getSession: mockGetSession,
      onAuthStateChange: mockOnAuthStateChange,
      signOut: mockSignOut,
    },
    from: vi.fn(() => ({
      upsert: vi.fn().mockResolvedValue({ error: null }),
    })),
  },
}))

// Test component that uses the auth context
function TestComponent() {
  const { user, isLoading, signOut } = useAuth()
  
  return (
    <div>
      <div data-testid="loading">{isLoading ? 'loading' : 'not-loading'}</div>
      <div data-testid="user">{user ? user.email : 'no-user'}</div>
      <button onClick={signOut}>Sign Out</button>
    </div>
  )
}

describe('AuthContext', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('useAuth() throws when called outside AuthProvider', () => {
    expect(() => {
      render(<TestComponent />)
    }).toThrow('useAuth must be used within AuthProvider')
  })

  it('AuthProvider exposes user, isLoading, and signOut', async () => {
    const mockUser: User = {
      id: 'test-user-id',
      email: 'test@example.com',
      app_metadata: {},
      user_metadata: {},
      aud: 'authenticated',
      created_at: '2024-01-01T00:00:00.000Z',
    }

    const mockSession: Session = {
      user: mockUser,
      access_token: 'test-token',
      refresh_token: 'test-refresh',
      expires_in: 3600,
      token_type: 'bearer',
    }

    // Mock getSession to return a session
    mockGetSession.mockResolvedValue({
      data: { session: mockSession },
      error: null,
    })

    // Mock onAuthStateChange
    const mockUnsubscribe = vi.fn()
    mockOnAuthStateChange.mockReturnValue({
      data: {
        subscription: { unsubscribe: mockUnsubscribe },
      },
    })

    render(
      <AuthProvider>
        <TestComponent />
      </AuthProvider>
    )

    // Initially loading
    expect(screen.getByTestId('loading')).toHaveTextContent('loading')

    // Wait for session to load
    await waitFor(() => {
      expect(screen.getByTestId('loading')).toHaveTextContent('not-loading')
    })

    expect(screen.getByTestId('user')).toHaveTextContent('test@example.com')
  })

  it('handles no session gracefully', async () => {
    // Mock getSession to return no session
    mockGetSession.mockResolvedValue({
      data: { session: null },
      error: null,
    })

    // Mock onAuthStateChange
    const mockUnsubscribe = vi.fn()
    mockOnAuthStateChange.mockReturnValue({
      data: {
        subscription: { unsubscribe: mockUnsubscribe },
      },
    })

    render(
      <AuthProvider>
        <TestComponent />
      </AuthProvider>
    )

    await waitFor(() => {
      expect(screen.getByTestId('loading')).toHaveTextContent('not-loading')
    })

    expect(screen.getByTestId('user')).toHaveTextContent('no-user')
  })

  it('signOut() calls supabase.auth.signOut()', async () => {
    // Mock getSession
    mockGetSession.mockResolvedValue({
      data: { session: null },
      error: null,
    })

    // Mock onAuthStateChange
    const mockUnsubscribe = vi.fn()
    mockOnAuthStateChange.mockReturnValue({
      data: {
        subscription: { unsubscribe: mockUnsubscribe },
      },
    })

    // Mock signOut
    mockSignOut.mockResolvedValue({ error: null })

    render(
      <AuthProvider>
        <TestComponent />
      </AuthProvider>
    )

    await waitFor(() => {
      expect(screen.getByTestId('loading')).toHaveTextContent('not-loading')
    })

    // Click sign out button
    const signOutButton = screen.getByText('Sign Out')
    await signOutButton.click()

    expect(mockSignOut).toHaveBeenCalledTimes(1)
  })

  it('cleans up auth state listener on unmount', async () => {
    // Mock getSession
    mockGetSession.mockResolvedValue({
      data: { session: null },
      error: null,
    })

    // Mock onAuthStateChange
    const mockUnsubscribe = vi.fn()
    mockOnAuthStateChange.mockReturnValue({
      data: {
        subscription: { unsubscribe: mockUnsubscribe },
      },
    })

    const { unmount } = render(
      <AuthProvider>
        <TestComponent />
      </AuthProvider>
    )

    await waitFor(() => {
      expect(screen.getByTestId('loading')).toHaveTextContent('not-loading')
    })

    // Unmount the component
    unmount()

    // Should unsubscribe from auth state changes
    expect(mockUnsubscribe).toHaveBeenCalledTimes(1)
  })

  it('handles auth state changes', async () => {
    const mockUser: User = {
      id: 'test-user-id',
      email: 'test@example.com',
      app_metadata: {},
      user_metadata: {},
      aud: 'authenticated',
      created_at: '2024-01-01T00:00:00.000Z',
    }

    const mockSession: Session = {
      user: mockUser,
      access_token: 'test-token',
      refresh_token: 'test-refresh',
      expires_in: 3600,
      token_type: 'bearer',
    }

    // Mock initial getSession to return no session
    mockGetSession.mockResolvedValue({
      data: { session: null },
      error: null,
    })

    // Mock onAuthStateChange and capture the callback
    let authStateCallback: ((event: string, session: Session | null) => void) | null = null
    const mockUnsubscribe = vi.fn()
    mockOnAuthStateChange.mockImplementation((callback) => {
      authStateCallback = callback as any
      return {
        data: {
          subscription: { unsubscribe: mockUnsubscribe },
        },
      }
    })

    render(
      <AuthProvider>
        <TestComponent />
      </AuthProvider>
    )

    await waitFor(() => {
      expect(screen.getByTestId('loading')).toHaveTextContent('not-loading')
    })

    // Initially no user
    expect(screen.getByTestId('user')).toHaveTextContent('no-user')

    // Simulate auth state change (user signs in)
    act(() => {
      if (authStateCallback) {
        authStateCallback('SIGNED_IN', mockSession)
      }
    })

    // Should show the new user
    expect(screen.getByTestId('user')).toHaveTextContent('test@example.com')
  })
})
