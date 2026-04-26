import { useState } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/features/auth/store/authStore'
import { Button } from '@/components/Button'
import { Input } from '@/components/Input'
import type { SignUpCredentials } from '@/types/auth'

export function SignupPage() {
  const navigate = useNavigate()
  const setUser = useAuthStore((state) => state.setUser)

  const [credentials, setCredentials] = useState<SignUpCredentials>({
    email: '',
    password: '',
    name: '',
  })
  const [error, setError] = useState('')
  const [isLoading, setIsLoading] = useState(false)

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
      const { data, error: signUpError } = await supabase.auth.signUp({
        email: credentials.email,
        password: credentials.password,
        options: {
          data: {
            name: credentials.name,
          },
        },
      })

      if (signUpError) throw signUpError

      if (data.user) {
        setUser({ id: data.user.id, email: data.user.email || '' })
        navigate('/dashboard')
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to sign up')
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 px-4">
      <div className="max-w-md w-full space-y-8">
        <div>
          <h2 className="text-3xl font-bold text-center text-primary">
            Create Account
          </h2>
          <p className="mt-2 text-center text-gray-600">
            Join EchoMirror today
          </p>
        </div>

        <form className="mt-8 space-y-6" onSubmit={handleSubmit}>
          <Input
            label="Name (optional)"
            type="text"
            value={credentials.name || ''}
            onChange={(e) =>
              setCredentials({ ...credentials, name: e.target.value })
            }
            placeholder="Your name"
          />

          <Input
            label="Email"
            type="email"
            value={credentials.email}
            onChange={(e) =>
              setCredentials({ ...credentials, email: e.target.value })
            }
            error={error && !credentials.email ? error : ''}
            placeholder="you@example.com"
          />

          <Input
            label="Password"
            type="password"
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

          <Button
            type="submit"
            isLoading={isLoading}
            className="w-full"
          >
            Sign Up
          </Button>

          <div className="text-center">
            <p className="text-sm text-gray-600">
              Already have an account?{' '}
              <Link
                to="/login"
                className="text-primary hover:text-primary-600 font-medium"
              >
                Sign in
              </Link>
            </p>
          </div>
        </form>
      </div>
    </div>
  )
}
