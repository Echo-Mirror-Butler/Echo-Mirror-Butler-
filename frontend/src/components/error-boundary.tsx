import { Component, type ErrorInfo, type ReactNode } from 'react'
import { useLocation } from 'react-router-dom'
import { useAuth } from '../lib/auth-context'
import { generateErrorReferenceCode } from '../lib/error-reference'

type BoundaryProps = {
  children: ReactNode
  routeName?: string
  routePath?: string
  userId?: string
}

type BoundaryState = {
  hasError: boolean
  message: string
  referenceCode: string
}

export class ErrorBoundary extends Component<BoundaryProps, BoundaryState> {
  state: BoundaryState = { hasError: false, message: '', referenceCode: '' }

  static getDerivedStateFromError(error: Error): BoundaryState {
    return {
      hasError: true,
      message: error.message,
      referenceCode: generateErrorReferenceCode(),
    }
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    const routeName = this.props.routeName ?? 'Unknown route'
    const routePath = this.props.routePath ?? window.location.pathname
    const userId = this.props.userId ?? 'anonymous'
    const timestamp = new Date().toISOString()

    console.warn(
      `[EchoMirror route error] ref=${this.state.referenceCode} route=${routeName} path=${routePath} user=${userId} at=${timestamp}`,
      error,
      errorInfo.componentStack,
    )
  }

  render() {
    if (this.state.hasError) {
      const routeName = this.props.routeName ?? 'This page'

      return (
        <section className="card empty-state route-error-card">
          <p className="chip">Reference {this.state.referenceCode}</p>
          <h2>This page ran into a problem</h2>
          <p className="muted">
            {routeName} could not finish loading. The rest of EchoMirror is still available from the navigation.
          </p>
          <p className="error-text">{this.state.message}</p>
          <div className="route-error-actions">
            <button type="button" onClick={() => window.location.reload()}>
              Reload page
            </button>
            <a className="button-link" href="/dashboard">
              Go to Dashboard
            </a>
          </div>
        </section>
      )
    }

    return this.props.children
  }
}

export function RouteErrorBoundary({ children, routeName }: { children: ReactNode; routeName: string }) {
  const location = useLocation()
  const { user } = useAuth()

  return (
    <ErrorBoundary routeName={routeName} routePath={location.pathname} userId={user?.id}>
      {children}
    </ErrorBoundary>
  )
}
