import { useState } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '@/lib/supabase'
import { Button } from '@/components/Button'
import { Input } from '@/components/Input'
import type { ResetPasswordCredentials } from '@/types/auth'

export function ResetPasswordPage() {
  const [credentials, setCredentials] = useState<ResetPasswordCredentials>({
    email: '',
  })
  const [error, setError] = useState('')
  const [success, setSuccess] = useState(false)
  const [isLoading, setIsLoading] = useState(false)

  const validateForm = (): string | null => {
    if (!credentials.email) return 'Email is required'
    if (!credentials.email.includes('@')) return 'Invalid email address'
    return null
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setSuccess(false)

    const validationError = validateForm()
    if (validationError) {
      setError(validationError)
      return
    }

    setIsLoading(true)

    try {
      const { error: resetError } = await supabase.auth.resetPasswordForEmail(
        credentials.email,
        {
          redirectTo: `${window.location.origin}/update-password`,
        }
      )

      if (resetError) throw resetError

      setSuccess(true)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to send reset email')
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 px-4">
      <div className="max-w-md w-full space-y-8">
        <div>
          <h2 className="text-3xl font-bold text-center text-primary">
            Reset Password
          </h2>
          <p className="mt-2 text-center text-gray-600">
            Enter your email to receive a password reset link
          </p>
        </div>

        {success ? (
          <div className="bg-green-50 border border-green-200 text-green-700 px-4 py-6 rounded">
            <p className="font-medium mb-2">Check your email</p>
            <p className="text-sm">
              We've sent a password reset link to {credentials.email}. Click the
              link in the email to set your new password.
            </p>
            <div className="mt-4">
              <Link
                to="/login"
                className="text-primary hover:text-primary-600 font-medium"
              >
                Back to login
              </Link>
            </div>
          </div>
        ) : (
          <form className="mt-8 space-y-6" onSubmit={handleSubmit}>
            <Input
              label="Email"
              type="email"
              value={credentials.email}
              onChange={(e) =>
                setCredentials({ ...credentials, email: e.target.value })
              }
              error={error}
              placeholder="you@example.com"
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
              Send Reset Link
            </Button>

            <div className="text-center">
              <Link
                to="/login"
                className="text-sm text-primary hover:text-primary-600"
              >
                Back to login
              </Link>
            </div>
          </form>
        )}
      </div>
    </div>
  )
}
