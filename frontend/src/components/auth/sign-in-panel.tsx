import { FormEvent, useState } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";
import { supabase } from "../../lib/supabase";
import "../../features/landing/landing-page.css";

const REDIRECT_URL = `${window.location.origin}/auth/callback`

async function signInWithOAuth(provider: 'google' | 'github') {
  await supabase.auth.signInWithOAuth({ provider, options: { redirectTo: REDIRECT_URL } })
}

export function SignInPanel() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
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
      // Redirect to the page they were trying to access, or dashboard as fallback
      const from = (location.state as { from?: string })?.from || "/dashboard";
      navigate(from, { replace: true });
    }
  };

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
              <span
                className="lp-auth-chip-dot"
                style={{ background: c.color }}
              />
              {c.label}
            </span>
          ))}
        </div>
      </div>

      <div className="lp-auth-right">
        <div className="lp-auth-card">
          <h2 className="lp-auth-card-title">Sign in</h2>
          <p className="lp-auth-card-sub">
            Enter your credentials to continue.
          </p>

          <div className="lp-oauth-btns">
            <button type="button" className="lp-oauth-btn" onClick={() => signInWithOAuth('google')} aria-label="Continue with Google">
              <svg width="18" height="18" viewBox="0 0 48 48" aria-hidden="true"><path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/><path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/><path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/><path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/><path fill="none" d="M0 0h48v48H0z"/></svg>
              Continue with Google
            </button>
            <button type="button" className="lp-oauth-btn" onClick={() => signInWithOAuth('github')} aria-label="Continue with GitHub">
              <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true" fill="currentColor"><path d="M12 0C5.37 0 0 5.37 0 12c0 5.3 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61-.546-1.385-1.335-1.755-1.335-1.755-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 21.795 24 17.295 24 12c0-6.63-5.37-12-12-12"/></svg>
              Continue with GitHub
            </button>
          </div>

          <div className="lp-auth-divider" style={{ margin: '1rem 0' }}>
            <span /><em>or sign in with email</em><span />
          </div>

          <form onSubmit={onSubmit} className="lp-auth-form">
            <div className="lp-auth-field">
              <label className="lp-auth-label" htmlFor="si-email">
                Email
              </label>
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
              <label className="lp-auth-label" htmlFor="si-pass">
                Password
              </label>
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

            <button
              type="submit"
              className="lp-auth-submit"
              disabled={isSubmitting}
            >
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
