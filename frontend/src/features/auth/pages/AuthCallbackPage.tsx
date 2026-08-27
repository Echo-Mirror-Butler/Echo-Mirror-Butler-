import { useEffect, useState } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { supabase } from '../../../lib/supabase'

/**
 * OAuth / magic-link / email-confirm callback.
 * Issue #634: reject missing/tampered codes, clear any pre-existing session
 * before exchanging (session-fixation mitigation), and rely on Supabase PKCE
 * for CSRF protection of the authorization code.
 */
export function AuthCallbackPage() {
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const [status, setStatus] = useState('Signing you in…')

  useEffect(() => {
    let cancelled = false

    const run = async () => {
      const errorParam =
        searchParams.get('error') ||
        searchParams.get('error_description') ||
        searchParams.get('error_code')

      if (errorParam) {
        navigate(`/login?error=${encodeURIComponent(errorParam)}`, { replace: true })
        return
      }

      const code = searchParams.get('code')
      if (!code) {
        // Tampered or incomplete callback — do not silently accept
        navigate('/login?error=missing_code', { replace: true })
        return
      }

      // Mitigate session fixation: drop any existing local session first
      try {
        await supabase.auth.signOut({ scope: 'local' })
      } catch {
        // Ignore — exchange will still validate the PKCE verifier
      }

      if (cancelled) return

      const { data, error } = await supabase.auth.exchangeCodeForSession(code)

      // Strip sensitive query params from the address bar
      try {
        window.history.replaceState({}, document.title, '/auth/callback')
      } catch {
        // ignore
      }

      if (cancelled) return

      if (error || !data.session) {
        navigate('/login?error=oauth_failed', { replace: true })
        return
      }

      const next = searchParams.get('next')
      if (next === '/update-password') {
        navigate('/update-password', { replace: true })
        return
      }

      const user = data.session.user
      if (user && !user.user_metadata?.onboarding_completed) {
        navigate('/onboarding', { replace: true })
      } else {
        navigate('/dashboard', { replace: true })
      }
    }

    setStatus('Signing you in…')
    void run()

    return () => {
      cancelled = true
    }
  }, [navigate, searchParams])

  return (
    <div
      style={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
      role="status"
      aria-live="polite"
    >
      <p style={{ color: 'var(--muted, #6b7280)', fontSize: '0.95rem' }}>{status}</p>
    </div>
  )
}
