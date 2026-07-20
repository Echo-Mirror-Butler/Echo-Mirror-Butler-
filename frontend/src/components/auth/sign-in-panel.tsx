import { FormEvent, useState } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";
import { supabase } from "../../lib/supabase";
import "../../features/landing/landing-page.css";

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
