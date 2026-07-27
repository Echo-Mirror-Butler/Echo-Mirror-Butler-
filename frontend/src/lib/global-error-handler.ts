import { captureSentryException } from './sentry'

export function initializeGlobalErrorHandler() {
  window.addEventListener('unhandledrejection', (event) => {
    console.error('Unhandled promise rejection:', {
      reason: event.reason,
      promise: event.promise,
      timestamp: new Date().toISOString(),
    })

    captureSentryException(event.reason, {
      type: 'unhandledrejection',
      timestamp: new Date().toISOString(),
    })

    const message = event.reason instanceof Error
      ? event.reason.message
      : String(event.reason)

    const toastEvent = new CustomEvent('app:show-toast', {
      detail: {
        message: `Unexpected error: ${message}`,
        type: 'error',
      },
    })
    window.dispatchEvent(toastEvent)

    event.preventDefault()
  })

  window.addEventListener('error', (event) => {
    console.error('Unhandled error:', {
      message: event.message,
      filename: event.filename,
      lineno: event.lineno,
      colno: event.colno,
      error: event.error,
      timestamp: new Date().toISOString(),
    })

    captureSentryException(event.error ?? new Error(event.message), {
      type: 'window.error',
      filename: event.filename,
      lineno: event.lineno,
      colno: event.colno,
      timestamp: new Date().toISOString(),
    })
  })
}
