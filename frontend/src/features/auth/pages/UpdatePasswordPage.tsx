import { FormEvent, useEffect, useState } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { supabase } from '../../../lib/supabase'
import { useAuth } from '../../../lib/auth-context'
import '../../landing/landing-page.css'

/**
 * Set a new password after recovery, or change password while logged in.
 * Issue #634: do not trust raw access_token query params. Accept only a
 * live session established via PKCE code exchange (PASSWORD_RECOVERY) or
 * an already-authenticated user.
 */
export function UpdatePasswordPage() {
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const { user } = useAuth()

  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState<string | null>(null)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [ready, setReady] = useState(Boolean(user))
  const [isRecovery, setIsRecovery] = useState(false)

  useEffect(() => {
    let cancelled = false
    let recoveryDetected = false

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((event) => {
      if (event === 'PASSWORD_RECOVERY') {
        recoveryDetected = true
        if (!cancelled) {
          setIsRecovery(true)
          setReady(true)
          setError(null)
        }
      }
    })

    const bootstrap = async () => {
      // Reject legacy / tampered query tokens — never establish a session from them
      const tamperedToken =
        searchParams.get('access_token') ||
        searchParams.get('refresh_token') ||
        searchParams.get('token')
      if (tamperedToken && !searchParams.get('code')) {
        if (!cancelled) {
          setError('Invalid or expired reset link')
          setReady(false)
        }
        return
      }

      const code = searchParams.get('code')
      if (code) {
        try {
          await supabase.auth.signOut({ scope: 'local' })
        } catch {
          // ignore
        }
        const { data, error: exchangeError } =
          await supabase.auth.exchangeCodeForSession(code)
        try {
          window.history.replaceState({}, document.title, '/update-password')
        } catch {
          // ignore
        }
        if (cancelled) return
        if (exchangeError || !data.session) {
          setError('Invalid or expired reset link')
          setReady(false)
          return
        }
        setIsRecovery(true)
        setReady(true)
        return
      }

      // Already authenticated (settings → change password)
      const { data } = await supabase.auth.getSession()
      if (cancelled) return
      if (data.session?.user || user) {
        setReady(true)
        return
      }

      // Wait briefly for PASSWORD_RECOVERY event from hash fragment flows
      await new Promise((r) => setTimeout(r, 400))
      if (cancelled) return
      if (recoveryDetected) return

      const again = await supabase.auth.getSession()
      if (cancelled) return
      if (again.data.session?.user) {
        setReady(true)
      } else {
        setError('Invalid or expired reset link')
        setReady(false)
      }
    }

    void bootstrap()

    return () => {
      cancelled = true
      subscription.unsubscribe()
    }
  }, [searchParams, user])

  const onSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    setError(null)
    setSuccess(null)
    if (password.length < 6) {
      setError('Password must be at least 6 characters')
      return
    }
    if (password !== confirmPassword) {
      setError('Passwords do not match')
      return
    }

    const { data: sessionData } = await supabase.auth.getSession()
    if (!sessionData.session) {
      setError('Invalid or expired reset link')
      return
    }

    setIsSubmitting(true)
    const { error: err } = await supabase.auth.updateUser({ password })
    setIsSubmitting(false)
    if (err) {
      setError(err.message)
      return
    }

    setSuccess('Password updated successfully.')
    setPassword('')
    setConfirmPassword('')
    if (isRecovery || !user) {
      // Force a clean re-login after recovery
      await supabase.auth.signOut()
      navigate('/login')
    }
  }

  return (
    <div className="lp-auth-overlay">
      <div className="lp-auth-left">
        <div className="lp-auth-mesh" />
        <div className="lp-auth-lines">
          <div className="lp-auth-line" />
          <div className="lp-auth-line" />
          <div className="lp-auth-line" />
        </div>

        <div className="lp-auth-brand">
          <div className="lp-auth-mark">
            <img src="/app-icon.png" alt="EchoMirror" />
          </div>
          <span className="lp-auth-wordmark">EchoMirror</span>
        </div>

        <div className="lp-auth-hero-copy">
          <div className="lp-auth-hero-eyebrow">Almost there</div>
          <h2 className="lp-auth-hero-title">
            Set your
            <br />
            <em>new password.</em>
          </h2>
          <p className="lp-auth-hero-body">
            Choose something strong. Your account and all your data will be right where you left
            them.
          </p>
        </div>
      </div>

      <div className="lp-auth-right">
        <div className="lp-auth-card">
          <h2 className="lp-auth-card-title">New password</h2>
          <p className="lp-auth-card-sub">At least 6 characters. Make it count.</p>

          {!ready && error ? (
            <div className="lp-auth-error">{error}</div>
          ) : (
            <form onSubmit={onSubmit} className="lp-auth-form">
              <div className="lp-auth-field">
                <label className="lp-auth-label" htmlFor="up-pass">
                  New password
                </label>
                <input
                  id="up-pass"
                  className="lp-auth-input"
                  type="password"
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  autoComplete="new-password"
                  disabled={!ready}
                />
              </div>
              <div className="lp-auth-field">
                <label className="lp-auth-label" htmlFor="up-confirm">
                  Confirm password
                </label>
                <input
                  id="up-confirm"
                  className="lp-auth-input"
                  type="password"
                  required
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  placeholder="••••••••"
                  autoComplete="new-password"
                  disabled={!ready}
                />
              </div>
              {error && <div className="lp-auth-error">{error}</div>}
              {success && (
                <div
                  style={{
                    color: 'var(--success, #22c55e)',
                    fontSize: '0.88rem',
                    margin: '0.5rem 0',
                  }}
                >
                  {success}
                </div>
              )}
              <button
                type="submit"
                className="lp-auth-submit"
                disabled={isSubmitting || !ready}
              >
                {isSubmitting ? 'Updating…' : 'Update password'}
              </button>
              {user && !isRecovery && (
                <button
                  type="button"
                  className="lp-auth-link"
                  onClick={() => navigate('/settings')}
                >
                  Back to settings
                </button>
              )}
            </form>
          )}
        </div>
      </div>
    </div>
  )
}
