import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '@/lib/supabase'

export function AuthCallbackPage() {
  const navigate = useNavigate()
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const handleCallback = async () => {
      try {
        const { data, error: sessionError } = await supabase.auth.exchangeCodeForSession(
          window.location.search,
        )

        if (sessionError) throw sessionError

        const user = data.session?.user
        if (!user) throw new Error('No user in session')

        // Route new OAuth users to onboarding, returning users to dashboard
        const isNewUser = !user.user_metadata?.onboarding_completed
        navigate(isNewUser ? '/onboarding' : '/dashboard', { replace: true })
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Authentication failed')
      }
    }

    void handleCallback()
  }, [navigate])

  if (error) {
    return (
      <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: '1rem' }}>
        <p style={{ color: 'var(--error, #ef4444)' }}>Sign-in failed: {error}</p>
        <a href="/login" style={{ color: 'var(--brand)' }}>Back to login</a>
      </div>
    )
  }

  return (
    <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <p>Completing sign-in…</p>
    </div>
  )
}
