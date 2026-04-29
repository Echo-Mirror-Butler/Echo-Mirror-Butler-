import { Component, ReactNode } from 'react'

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
        <section className="card empty-state">
          <h2>Something went wrong</h2>
          <p>{this.state.message}</p>
          <button type="button" onClick={() => this.setState({ hasError: false, message: '' })}>
            Try again
          </button>
        </section>
      )
    }

    return this.props.children
  }
}
