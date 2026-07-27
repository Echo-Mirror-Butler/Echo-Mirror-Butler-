import * as Sentry from '@sentry/react'

const dsn = import.meta.env.VITE_SENTRY_DSN
const environment = import.meta.env.VITE_APP_ENV ?? 'development'

export function initSentry() {
  if (!dsn) return

  Sentry.init({
    dsn,
    environment,
    tracesSampleRate: environment === 'production' ? 0.2 : 1.0,
    replaysSessionSampleRate: environment === 'production' ? 0.1 : 0.5,
    replaysOnErrorSampleRate: 1.0,
    integrations: [
      Sentry.browserTracingIntegration(),
      Sentry.replayIntegration({ maskAllText: true, blockAllMedia: true }),
    ],
    beforeSend(event) {
      // Strip PII — never send email or user metadata
      if (event.user) {
        event.user = { id: event.user.id }
      }
      return event
    },
  })
}

export function setSentryUser(userId: string | null) {
  if (!userId) {
    Sentry.setUser(null)
    return
  }
  Sentry.setUser({ id: userId })
}

export function captureSentryException(error: unknown, context?: Record<string, unknown>) {
  Sentry.withScope((scope) => {
    if (context) {
      for (const [key, value] of Object.entries(context)) {
        scope.setExtra(key, value)
      }
    }
    Sentry.captureException(error)
  })
}
