import { render, screen, waitFor, act } from '@testing-library/react'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { AuthProvider, useAuth } from './auth-context'
import type { Session, User } from '@supabase/supabase-js'

// Mock supabase
vi.mock('./supabase', () => ({
  supabase: {
    auth: {
      getSession: vi.fn(),
      onAuthStateChange: vi.fn(),
      signOut: vi.fn(),
    },
  },
}))

const mockSupabase = vi.mocked(await import('./supabase')).supabase

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
    mockSupabase.auth.getSession.mockResolvedValue({
      data: { session: mockSession },
      error: null,
    })

    // Mock onAuthStateChange
    const mockUnsubscribe = vi.fn()
    mockSupabase.auth.onAuthStateChange.mockReturnValue({
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
    mockSupabase.auth.getSession.mockResolvedValue({
      data: { session: null },
      error: null,
    })

    // Mock onAuthStateChange
    const mockUnsubscribe = vi.fn()
    mockSupabase.auth.onAuthStateChange.mockReturnValue({
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
    mockSupabase.auth.getSession.mockResolvedValue({
      data: { session: null },
      error: null,
    })

    // Mock onAuthStateChange
    const mockUnsubscribe = vi.fn()
    mockSupabase.auth.onAuthStateChange.mockReturnValue({
      data: {
        subscription: { unsubscribe: mockUnsubscribe },
      },
    })

    // Mock signOut
    mockSupabase.auth.signOut.mockResolvedValue({ error: null })

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

    expect(mockSupabase.auth.signOut).toHaveBeenCalledTimes(1)
  })

  it('cleans up auth state listener on unmount', async () => {
    // Mock getSession
    mockSupabase.auth.getSession.mockResolvedValue({
      data: { session: null },
      error: null,
    })

    // Mock onAuthStateChange
    const mockUnsubscribe = vi.fn()
    mockSupabase.auth.onAuthStateChange.mockReturnValue({
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
    mockSupabase.auth.getSession.mockResolvedValue({
      data: { session: null },
      error: null,
    })

    // Mock onAuthStateChange and capture the callback
    let authStateCallback: ((event: string, session: Session | null) => void) | null = null
    const mockUnsubscribe = vi.fn()
    mockSupabase.auth.onAuthStateChange.mockImplementation((callback) => {
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
