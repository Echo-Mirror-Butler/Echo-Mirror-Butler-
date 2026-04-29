import { FormEvent, useState } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../../lib/supabase'

export function SignInPanel() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const onSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    setIsSubmitting(true)
    setError(null)

    const { error: authError } = await supabase.auth.signInWithPassword({
      email,
      password,
    })

    setIsSubmitting(false)

    if (authError) {
      setError(authError.message)
    }
  }

  return (
    <section className="auth-panel animate-rise">
      <h1>EchoMirror Web</h1>
      <p>Sign in to manage your wallet, logs, and AI insight history.</p>
      <form onSubmit={onSubmit} className="auth-form">
        <label>
          Email
          <input
            type="email"
            required
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            placeholder="you@example.com"
          />
        </label>
        <label>
          Password
          <input
            type="password"
            required
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            placeholder="••••••••"
          />
        </label>
        <button type="submit" disabled={isSubmitting}>
          {isSubmitting ? 'Signing in…' : 'Sign in'}
        </button>
        {error ? <p className="error-text">{error}</p> : null}
      </form>
      <div className="auth-links">
        <p>
          Don&apos;t have an account? <Link to="/signup">Sign up</Link>
        </p>
        <p>
          Forgot your password? <Link to="/reset-password">Reset it</Link>
        </p>
      </div>
    </section>
  )
}
