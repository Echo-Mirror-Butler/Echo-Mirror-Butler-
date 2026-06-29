import { useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../../../lib/supabase'

export function AuthCallbackPage() {
  const navigate = useNavigate()

  useEffect(() => {
    supabase.auth.exchangeCodeForSession(window.location.href).then(({ data, error }) => {
      if (error) {
        navigate('/login?error=oauth_failed', { replace: true })
        return
      }
      const user = data.session?.user
      if (user && !user.user_metadata?.onboarding_completed) {
        navigate('/onboarding', { replace: true })
      } else {
        navigate('/dashboard', { replace: true })
      }
    })
  }, [navigate])

  return (
    <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <p style={{ color: 'var(--muted, #6b7280)', fontSize: '0.95rem' }}>Signing you in…</p>
    </div>
  )
}
