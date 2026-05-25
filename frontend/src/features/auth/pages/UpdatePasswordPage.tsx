import { FormEvent, useState } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { supabase } from '../../../lib/supabase'
import '../../landing/landing-page.css'

export function UpdatePasswordPage() {
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const accessToken = searchParams.get('access_token')

  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [isSubmitting, setIsSubmitting] = useState(false)

  const onSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    setError(null)
    if (password.length < 6) { setError('Password must be at least 6 characters'); return }
    if (!accessToken) { setError('Invalid or expired reset link'); return }
    setIsSubmitting(true)
    const { error: err } = await supabase.auth.updateUser({ password })
    setIsSubmitting(false)
    if (err) { setError(err.message) } else { navigate('/login') }
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
            Set your<br />
            <em>new password.</em>
          </h2>
          <p className="lp-auth-hero-body">
            Choose something strong. Your account and all your data will be
            right where you left them.
          </p>
        </div>
      </div>

      <div className="lp-auth-right">
        <div className="lp-auth-card">
          <h2 className="lp-auth-card-title">New password</h2>
          <p className="lp-auth-card-sub">At least 6 characters. Make it count.</p>

          <form onSubmit={onSubmit} className="lp-auth-form">
            <div className="lp-auth-field">
              <label className="lp-auth-label" htmlFor="up-pass">New password</label>
              <input id="up-pass" className="lp-auth-input" type="password" required
                value={password} onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••" autoComplete="new-password" />
            </div>
            {error && <div className="lp-auth-error">{error}</div>}
            <button type="submit" className="lp-auth-submit" disabled={isSubmitting}>
              {isSubmitting ? 'Updating…' : 'Update password'}
            </button>
          </form>
        </div>
      </div>
    </div>
  )
}
