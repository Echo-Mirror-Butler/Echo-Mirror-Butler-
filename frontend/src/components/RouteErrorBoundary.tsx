import { Component, ReactNode } from 'react'
import { Link } from 'react-router-dom'

interface Props {
  children: ReactNode
  routeName?: string
}

interface State {
  hasError: boolean
  error: Error | null
  errorInfo: React.ErrorInfo | null
  referenceCode: string
}

export class RouteErrorBoundary extends Component<Props, State> {
  state: State = {
    hasError: false,
    error: null,
    errorInfo: null,
    referenceCode: '',
  }

  static getDerivedStateFromError(error: Error): Partial<State> {
    const referenceCode = crypto.randomUUID().slice(0, 8).toUpperCase()
    return {
      hasError: true,
      error,
      referenceCode,
    }
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    const { routeName } = this.props
    const { referenceCode } = this.state

    console.error('Route error boundary caught an error:', {
      routeName: routeName || 'Unknown route',
      error: error.message,
      stack: error.stack,
      componentStack: errorInfo.componentStack,
      referenceCode,
      timestamp: new Date().toISOString(),
    })

    this.setState({ errorInfo })

    this.logErrorToService(error, errorInfo, referenceCode)
  }

  async logErrorToService(error: Error, errorInfo: React.ErrorInfo, referenceCode: string) {
    try {
      const { supabase } = await import('@/lib/supabase')
      const { data: { user } } = await supabase.auth.getUser()

      await supabase.from('error_logs').insert({
        reference_code: referenceCode,
        error_message: error.message,
        error_stack: error.stack,
        component_stack: errorInfo.componentStack,
        route_path: window.location.pathname,
        user_id: user?.id || null,
        timestamp: new Date().toISOString(),
      })
    } catch (logError) {
      console.error('Failed to log error to service:', logError)
    }
  }

  handleReload = () => {
    window.location.reload()
  }

  render() {
    if (this.state.hasError) {
      const { routeName } = this.props
      const { referenceCode, error } = this.state

      return (
        <div className="min-h-screen flex items-center justify-center bg-gray-50 p-4">
          <div className="max-w-md w-full bg-white rounded-lg shadow-lg p-6">
            <div className="flex items-center justify-center w-16 h-16 mx-auto bg-red-100 rounded-full mb-4">
              <svg
                className="w-8 h-8 text-red-600"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                />
              </svg>
            </div>

            <h2 className="text-2xl font-bold text-center text-gray-900 mb-2">
              {routeName ? `${routeName} page` : 'This page'} ran into a problem
            </h2>

            <p className="text-gray-600 text-center mb-4">
              Something unexpected happened. You can try reloading the page or return to the
              dashboard.
            </p>

            <div className="bg-gray-100 rounded-lg p-3 mb-4">
              <p className="text-sm text-gray-700 mb-1">
                <strong>Reference Code:</strong>
              </p>
              <p className="text-lg font-mono text-gray-900">{referenceCode}</p>
              <p className="text-xs text-gray-500 mt-1">
                Quote this code when reporting the issue
              </p>
            </div>

            {error && (
              <details className="mb-4">
                <summary className="text-sm text-gray-600 cursor-pointer hover:text-gray-900">
                  Technical details
                </summary>
                <div className="mt-2 p-3 bg-gray-50 rounded text-xs font-mono text-gray-700 overflow-auto max-h-32">
                  {error.message}
                </div>
              </details>
            )}

            <div className="space-y-2">
              <button
                type="button"
                onClick={this.handleReload}
                className="w-full bg-blue-600 hover:bg-blue-700 text-white font-semibold py-3 px-4 rounded-lg transition-colors"
              >
                Reload page
              </button>

              <Link
                to="/dashboard"
                className="block w-full bg-gray-200 hover:bg-gray-300 text-gray-900 font-semibold py-3 px-4 rounded-lg text-center transition-colors"
              >
                Go to Dashboard
              </Link>
            </div>
          </div>
        </div>
      )
    }

    return this.props.children
  }
}
