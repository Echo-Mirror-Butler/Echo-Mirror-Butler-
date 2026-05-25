import { FormEvent, useState } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import { supabase } from '../../../lib/supabase'
import '../../landing/landing-page.css'

export function SignupPage() {
  const navigate = useNavigate()
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [isSubmitting, setIsSubmitting] = useState(false)

  const onSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    setError(null)
    if (!email.includes('@')) { setError('Enter a valid email address'); return }
    if (password.length < 6) { setError('Password must be at least 6 characters'); return }
    setIsSubmitting(true)
    const { error: err } = await supabase.auth.signUp({
      email, password, options: { data: { name } },
    })
    setIsSubmitting(false)
    if (err) { setError(err.message); return }
    navigate('/dashboard')
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
          <div className="lp-auth-hero-eyebrow">Join EchoMirror</div>
          <h2 className="lp-auth-hero-title">
            Every insight<br />
            starts with<br />
            <em>one moment.</em>
          </h2>
          <p className="lp-auth-hero-body">
            Free to start. Track your moods, get AI insights, and earn ECHO
            tokens on the Stellar network — no credit card required.
          </p>
        </div>

        <div className="lp-auth-chips">
          {['Free forever', 'AI-powered', 'Private by design', 'Earn ECHO tokens'].map((label, i) => (
            <span key={label} className="lp-auth-chip">
              <span className="lp-auth-chip-dot" style={{ background: i % 2 === 0 ? '#60a5fa' : '#34d399' }} />
              {label}
            </span>
          ))}
        </div>
      </div>

      <div className="lp-auth-right">
        <div className="lp-auth-card">
          <h2 className="lp-auth-card-title">Create account</h2>
          <p className="lp-auth-card-sub">Free forever. No credit card needed.</p>

          <form onSubmit={onSubmit} className="lp-auth-form">
            <div className="lp-auth-field">
              <label className="lp-auth-label" htmlFor="su-name">
                Name <span style={{ opacity: 0.45, fontWeight: 400, fontSize: '0.68rem' }}>(optional)</span>
              </label>
              <input id="su-name" className="lp-auth-input" type="text"
                value={name} onChange={(e) => setName(e.target.value)} placeholder="Your name" />
            </div>
            <div className="lp-auth-field">
              <label className="lp-auth-label" htmlFor="su-email">Email</label>
              <input id="su-email" className="lp-auth-input" type="email" required
                value={email} onChange={(e) => setEmail(e.target.value)} placeholder="you@example.com" autoComplete="email" />
            </div>
            <div className="lp-auth-field">
              <label className="lp-auth-label" htmlFor="su-pass">Password</label>
              <input id="su-pass" className="lp-auth-input" type="password" required
                value={password} onChange={(e) => setPassword(e.target.value)} placeholder="Min. 6 characters" autoComplete="new-password" />
            </div>

            {error && <div className="lp-auth-error">{error}</div>}

            <button type="submit" className="lp-auth-submit" disabled={isSubmitting}>
              {isSubmitting ? 'Creating account…' : 'Create account'}
            </button>
          </form>

          <div className="lp-auth-links">
            <div className="lp-auth-divider"><span /><em>already a member?</em><span /></div>
            <div className="lp-auth-link-row">
              <Link to="/login">Sign in to your account</Link>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
