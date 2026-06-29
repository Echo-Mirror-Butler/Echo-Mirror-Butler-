import { FormEvent, useState } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import { supabase } from '../../../lib/supabase'
import '../../landing/landing-page.css'

const REDIRECT_URL = `${window.location.origin}/auth/callback`

function GoogleIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 18 18" aria-hidden="true">
      <path fill="#4285F4" d="M17.64 9.2c0-.637-.057-1.251-.164-1.84H9v3.481h4.844c-.209 1.125-.843 2.078-1.796 2.717v2.258h2.908c1.702-1.567 2.684-3.875 2.684-6.615z"/>
      <path fill="#34A853" d="M9 18c2.43 0 4.467-.806 5.956-2.184l-2.908-2.258c-.806.54-1.837.86-3.048.86-2.344 0-4.328-1.584-5.036-3.711H.957v2.332A8.997 8.997 0 0 0 9 18z"/>
      <path fill="#FBBC05" d="M3.964 10.707A5.41 5.41 0 0 1 3.682 9c0-.593.102-1.17.282-1.707V4.961H.957A8.996 8.996 0 0 0 0 9c0 1.452.348 2.827.957 4.039l3.007-2.332z"/>
      <path fill="#EA4335" d="M9 3.58c1.321 0 2.508.454 3.44 1.345l2.582-2.58C13.463.891 11.426 0 9 0A8.997 8.997 0 0 0 .957 4.961L3.964 7.293C4.672 5.163 6.656 3.58 9 3.58z"/>
    </svg>
  )
}

function GitHubIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true" fill="currentColor">
      <path d="M12 0C5.37 0 0 5.373 0 12c0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 21.795 24 17.298 24 12c0-6.627-5.373-12-12-12z"/>
    </svg>
  )
}

async function signUpWithOAuth(provider: 'google' | 'github') {
  await supabase.auth.signInWithOAuth({ provider, options: { redirectTo: REDIRECT_URL } })
}

function getPasswordStrength(password: string): { score: number; label: string } {
  if (password.length < 8) return { score: 0, label: 'Weak' }
  const hasLetter = /[a-zA-Z]/.test(password)
  const hasNumber = /[0-9]/.test(password)
  const hasSymbol = /[^a-zA-Z0-9]/.test(password)
  const types = [hasLetter, hasNumber, hasSymbol].filter(Boolean).length
  if (types >= 2) return { score: 2, label: 'Strong' }
  return { score: 1, label: 'Fair' }
}

export function SignupPage() {
  const navigate = useNavigate()
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [isOAuthLoading, setIsOAuthLoading] = useState<'google' | 'github' | null>(null)

  const handleOAuth = async (provider: 'google' | 'github') => {
    setIsOAuthLoading(provider)
    setError(null)
    try {
      await signUpWithOAuth(provider)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'OAuth sign-up failed')
      setIsOAuthLoading(null)
    }
  }

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

          <div className="lp-oauth-group">
            <button
              type="button"
              className="lp-oauth-btn"
              onClick={() => handleOAuth('google')}
              disabled={!!isOAuthLoading}
              aria-label="Continue with Google"
            >
              <GoogleIcon />
              {isOAuthLoading === 'google' ? 'Redirecting…' : 'Continue with Google'}
            </button>
            <button
              type="button"
              className="lp-oauth-btn"
              onClick={() => handleOAuth('github')}
              disabled={!!isOAuthLoading}
              aria-label="Continue with GitHub"
            >
              <GitHubIcon />
              {isOAuthLoading === 'github' ? 'Redirecting…' : 'Continue with GitHub'}
            </button>
          </div>

          <div className="lp-auth-divider"><span /><em>or sign up with email</em><span /></div>

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
              {password.length > 0 && (
                <div className="ps-bar">
                  <div className="ps-bar-fill" data-strength={['weak', 'fair', 'strong'][getPasswordStrength(password).score]} style={{ width: `${((getPasswordStrength(password).score + 1) / 3) * 100}%` }} />
                  <span className="ps-label" data-strength={['weak', 'fair', 'strong'][getPasswordStrength(password).score]}>{getPasswordStrength(password).label}</span>
                </div>
              )}
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
