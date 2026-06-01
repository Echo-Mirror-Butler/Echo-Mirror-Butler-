import { Component, ReactNode } from 'react'
import { Link } from 'react-router-dom'

interface Props {
  children: ReactNode
}

interface State {
  hasError: boolean
  message: string
}

export class ErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false, message: '' }

  static getDerivedStateFromError(error: Error) {
    return { hasError: true, message: error.message }
  }

  render() {
    if (this.state.hasError) {
      return (
        <section className="feature-grid" style={{ minHeight: '60vh', alignContent: 'center' }}>
          <article className="card full-width" style={{ textAlign: 'center', padding: '3rem 2rem' }}>
            <h2 style={{ fontFamily: "'Fraunces', serif", fontSize: '1.8rem', margin: '0 0 0.5rem' }}>
              Something went wrong
            </h2>
            <p className="muted" style={{ margin: '0 0 1.5rem', fontSize: '0.95rem' }}>
              An unexpected error occurred. Try refreshing the page.
            </p>
            <div style={{ display: 'flex', gap: '0.75rem', justifyContent: 'center', flexWrap: 'wrap' }}>
              <button type="button" onClick={() => window.location.reload()}>
                Refresh page
              </button>
              <Link to="/dashboard" className="card" style={{ textDecoration: 'none', fontWeight: 600, background: 'var(--surface-soft)', color: 'var(--text)', display: 'inline-flex', alignItems: 'center' }}>
                Go to Dashboard
              </Link>
            </div>
            {import.meta.env.DEV && (
              <details style={{ marginTop: '1.5rem', textAlign: 'left' }}>
                <summary style={{ cursor: 'pointer', color: 'var(--muted)', fontSize: '0.85rem' }}>
                  Error details
                </summary>
                <pre style={{
                  marginTop: '0.5rem',
                  padding: '0.75rem',
                  borderRadius: '8px',
                  background: 'var(--surface-soft)',
                  border: '1px solid var(--line)',
                  fontSize: '0.8rem',
                  overflow: 'auto',
                  color: 'var(--danger)',
                }}>
                  {this.state.message}
                </pre>
              </details>
            )}
          </article>
        </section>
      )
    }

    return this.props.children
  }
}
