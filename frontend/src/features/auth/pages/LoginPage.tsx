import { useState } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/features/auth/store/authStore'
import { Button } from '@/components/Button'
import { Input } from '@/components/Input'
import type { SignInCredentials } from '@/types/auth'

export function LoginPage() {
  const navigate = useNavigate()
  const setUser = useAuthStore((state) => state.setUser)

  const [credentials, setCredentials] = useState<SignInCredentials>({
    email: '',
    password: '',
  })
  const [error, setError] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const [rememberMe, setRememberMe] = useState(
    () => localStorage.getItem('echo-remember-me') !== 'false',
  )

  const validateForm = (): string | null => {
    if (!credentials.email) return 'Email is required'
    if (!credentials.email.includes('@')) return 'Invalid email address'
    if (!credentials.password) return 'Password is required'
    if (credentials.password.length < 6) return 'Password must be at least 6 characters'
    return null
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')

    const validationError = validateForm()
    if (validationError) {
      setError(validationError)
      return
    }

    setIsLoading(true)

    try {
      const { data, error: signInError } = await supabase.auth.signInWithPassword({
        email: credentials.email,
        password: credentials.password,
      })

      if (signInError) throw signInError

      if (data.user) {
        setUser({ id: data.user.id, email: data.user.email || '' })
        navigate('/dashboard')
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to sign in')
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 px-4">
      <div className="max-w-md w-full space-y-8">
        <div>
          <h2 className="text-3xl font-bold text-center text-primary">
            Welcome Back
          </h2>
          <p className="mt-2 text-center text-gray-600">
            Sign in to your EchoMirror account
          </p>
        </div>

        <form className="mt-8 space-y-6" onSubmit={handleSubmit}>
          <Input
            label="Email"
            type="email" autoComplete="email"
            value={credentials.email}
            onChange={(e) =>
              setCredentials({ ...credentials, email: e.target.value })
            }
            error={error && !credentials.email ? error : ''}
            placeholder="you@example.com"
          />

          <Input
            label="Password"
            type="password" autoComplete="current-password"
            value={credentials.password}
            onChange={(e) =>
              setCredentials({ ...credentials, password: e.target.value })
            }
            error={error && credentials.email ? error : ''}
            placeholder="••••••••"
          />

          {error && (
            <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded">
              {error}
            </div>
          )}

          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <input
              id="remember-me"
              type="checkbox"
              checked={rememberMe}
              onChange={(e) => {
                const val = e.target.checked
                setRememberMe(val)
                localStorage.setItem('echo-remember-me', String(val))
              }}
              style={{ accentColor: 'var(--brand)', width: '1rem', height: '1rem', cursor: 'pointer' }}
            />
            <label
              htmlFor="remember-me"
              style={{ fontSize: '0.875rem', color: 'var(--muted)', cursor: 'pointer', userSelect: 'none' }}
            >
              Keep me signed in
            </label>
          </div>

          <Button
            type="submit"
            isLoading={isLoading}
            className="w-full"
          >
            Sign In
          </Button>

          <div className="text-center space-y-2">
            <Link
              to="/reset-password"
              className="text-sm text-primary hover:text-primary-600"
            >
              Forgot your password?
            </Link>
            <p className="text-sm text-gray-600">
              Don't have an account?{' '}
              <Link
                to="/signup"
                className="text-primary hover:text-primary-600 font-medium"
              >
                Sign up
              </Link>
            </p>
          </div>
        </form>
      </div>
    </div>
  )
}
