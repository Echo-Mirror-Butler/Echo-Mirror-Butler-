import { FormEvent, useState } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../../../lib/supabase'
import '../../landing/landing-page.css'

export function ResetPasswordPage() {
  const [email, setEmail] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)

  const onSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    setError(null)
    if (!email.includes('@')) { setError('Enter a valid email address'); return }
    setIsSubmitting(true)
    const { error: err } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/update-password`,
    })
    setIsSubmitting(false)
    if (err) { setError(err.message) } else { setSuccess(true) }
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
          <div className="lp-auth-hero-eyebrow">Account recovery</div>
          <h2 className="lp-auth-hero-title">
            Locked out?<br />
            <em>No worries.</em>
          </h2>
          <p className="lp-auth-hero-body">
            We'll send a secure link to your email. Your data, logs, and
            ECHO balance are all safe and waiting for you.
          </p>
        </div>
      </div>

      <div className="lp-auth-right">
        <div className="lp-auth-card">
          <h2 className="lp-auth-card-title">Reset password</h2>
          <p className="lp-auth-card-sub">We'll email you a secure reset link.</p>

          {success ? (
            <div className="lp-auth-success">
              <strong>Check your inbox</strong>
              A reset link was sent to <strong>{email}</strong>. Click it to set a new password — it expires in 1 hour.
              <div style={{ marginTop: '1rem' }}>
                <Link to="/login" style={{ color: '#1463ff', fontWeight: 500, fontSize: '0.82rem' }}>
                  ← Back to sign in
                </Link>
              </div>
            </div>
          ) : (
            <form onSubmit={onSubmit} className="lp-auth-form">
              <div className="lp-auth-field">
                <label className="lp-auth-label" htmlFor="rp-email">Email</label>
                <input id="rp-email" className="lp-auth-input" type="email" required
                  value={email} onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@example.com" autoComplete="email" />
              </div>
              {error && <div className="lp-auth-error">{error}</div>}
              <button type="submit" className="lp-auth-submit" disabled={isSubmitting}>
                {isSubmitting ? 'Sending…' : 'Send reset link'}
              </button>
            </form>
          )}

          <div className="lp-auth-links">
            <div className="lp-auth-link-row">
              <Link to="/login">← Back to sign in</Link>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
