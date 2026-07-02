import { FormEvent, useState } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";
import { supabase } from "../../lib/supabase";
import "../../features/landing/landing-page.css";

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

async function signInWithOAuth(provider: 'google' | 'github') {
  await supabase.auth.signInWithOAuth({ provider, options: { redirectTo: REDIRECT_URL } })
}

export function SignInPanel() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isOAuthLoading, setIsOAuthLoading] = useState<'google' | 'github' | null>(null);
  const [error, setError] = useState<string | null>(null);
  const location = useLocation();
  const navigate = useNavigate();

  const onSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setIsSubmitting(true);
    setError(null);
    const { error: authError } = await supabase.auth.signInWithPassword({
      email,
      password,
    });
    setIsSubmitting(false);
    if (authError) {
      setError(authError.message);
    } else {
      const from = (location.state as { from?: string })?.from || "/dashboard";
      navigate(from, { replace: true });
    }
  };

  const handleOAuth = async (provider: 'google' | 'github') => {
    setIsOAuthLoading(provider)
    setError(null)
    try {
      await signInWithOAuth(provider)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'OAuth sign-in failed')
      setIsOAuthLoading(null)
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
          <div className="lp-auth-hero-eyebrow">Welcome back</div>
          <h2 className="lp-auth-hero-title">
            Your mind,
            <br />
            <em>reflected</em>
            <br />
            back to you.
          </h2>
          <p className="lp-auth-hero-body">
            Pick up where you left off. Your logs, insights, and ECHO balance
            are right where you left them.
          </p>
        </div>

        <div className="lp-auth-chips">
          {[
            { label: "AI Insights", color: "#60a5fa" },
            { label: "Global Mirror", color: "#34d399" },
            { label: "Mood Logs", color: "#a78bfa" },
            { label: "ECHO Wallet", color: "#fbbf24" },
          ].map((c) => (
            <span key={c.label} className="lp-auth-chip">
              <span className="lp-auth-chip-dot" style={{ background: c.color }} />
              {c.label}
            </span>
          ))}
        </div>
      </div>

      <div className="lp-auth-right">
        <div className="lp-auth-card">
          <h2 className="lp-auth-card-title">Sign in</h2>
          <p className="lp-auth-card-sub">Enter your credentials to continue.</p>

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

          <div className="lp-auth-divider">
            <span />
            <em>or sign in with email</em>
            <span />
          </div>

          <form onSubmit={onSubmit} className="lp-auth-form">
            <div className="lp-auth-field">
              <label className="lp-auth-label" htmlFor="si-email">Email</label>
              <input
                id="si-email"
                className="lp-auth-input"
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@example.com"
                autoComplete="email"
              />
            </div>
            <div className="lp-auth-field">
              <label className="lp-auth-label" htmlFor="si-pass">Password</label>
              <input
                id="si-pass"
                className="lp-auth-input"
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                autoComplete="current-password"
              />
            </div>

            {error && <div className="lp-auth-error">{error}</div>}

            <button type="submit" className="lp-auth-submit" disabled={isSubmitting}>
              {isSubmitting ? "Signing in…" : "Sign in"}
            </button>
          </form>

          <div className="lp-auth-links">
            <div className="lp-auth-divider">
              <span />
              <em>new here?</em>
              <span />
            </div>
            <div className="lp-auth-link-row">
              No account? <Link to="/signup">Create one free</Link>
            </div>
            <div className="lp-auth-link-row">
              Forgot password? <Link to="/reset-password">Reset it</Link>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
