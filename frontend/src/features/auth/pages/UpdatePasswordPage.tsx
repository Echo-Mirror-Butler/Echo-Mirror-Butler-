import { useState } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { supabase } from '@/lib/supabase'
import { Button } from '@/components/Button'
import { Input } from '@/components/Input'
import type { UpdatePasswordCredentials } from '@/types/auth'

export function UpdatePasswordPage() {
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const accessToken = searchParams.get('access_token')

  const [credentials, setCredentials] = useState<UpdatePasswordCredentials>({
    password: '',
  })
  const [error, setError] = useState('')
  const [isLoading, setIsLoading] = useState(false)

  const validateForm = (): string | null => {
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

    if (!accessToken) {
      setError('Invalid or expired reset link')
      return
    }

    setIsLoading(true)

    try {
      const { error: updateError } = await supabase.auth.updateUser({
        password: credentials.password,
      })

      if (updateError) throw updateError

      navigate('/login')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update password')
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 px-4">
      <div className="max-w-md w-full space-y-8">
        <div>
          <h2 className="text-3xl font-bold text-center text-primary">
            Set New Password
          </h2>
          <p className="mt-2 text-center text-gray-600">
            Enter your new password below
          </p>
        </div>

        <form className="mt-8 space-y-6" onSubmit={handleSubmit}>
          <Input
            label="New Password"
            type="password"
            value={credentials.password}
            onChange={(e) =>
              setCredentials({ ...credentials, password: e.target.value })
            }
            error={error}
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
            Update Password
          </Button>
        </form>
      </div>
    </div>
  )
}
