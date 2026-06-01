import { Link } from 'react-router-dom'
import { useAuth } from '../../lib/auth-context'

export default function NotFoundPage() {
  const { user } = useAuth()

  return (
    <section className="feature-grid" style={{ minHeight: '60vh', alignContent: 'center' }}>
      <article className="card full-width" style={{ textAlign: 'center', padding: '3rem 2rem' }}>
        <div style={{ fontSize: '3.5rem', marginBottom: '0.5rem' }} aria-hidden="true">🔍</div>
        <h1 style={{
          fontFamily: "'Fraunces', serif",
          fontSize: 'clamp(3rem, 8vw, 5rem)',
          margin: '0 0 0.5rem',
          lineHeight: 1.1,
          color: 'var(--brand)',
        }}>
          404
        </h1>
        <p className="muted" style={{ fontSize: '1.1rem', margin: '0 0 1.5rem' }}>
          We couldn't find that page.
        </p>
        <div style={{ display: 'flex', gap: '0.75rem', justifyContent: 'center', flexWrap: 'wrap' }}>
          {user && <Link to="/dashboard" className="card" style={{ textDecoration: 'none', fontWeight: 600 }}>Go to Dashboard</Link>}
          <Link to="/" className="card" style={{ textDecoration: 'none', fontWeight: 600, background: 'var(--surface-soft)' }}>Go to Home</Link>
        </div>
      </article>
    </section>
  )
}
