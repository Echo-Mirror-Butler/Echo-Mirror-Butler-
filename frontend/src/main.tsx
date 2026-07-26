import React from 'react'
import ReactDOM from 'react-dom/client'
import { AppProviders } from './app/providers'
import { AppRouter } from './app/router'
import { validateEnv } from './lib/env-validation'
import { initSentry } from './lib/sentry'
import { initializeGlobalErrorHandler } from './lib/global-error-handler'
import './styles.css'
import './error-ui.css'

// Fail fast with a clear message if required env vars are absent or invalid.
validateEnv()

// Initialize Sentry before anything else so it captures bootstrap errors
initSentry()

initializeGlobalErrorHandler()

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <AppProviders>
      <AppRouter />
    </AppProviders>
  </React.StrictMode>,
)
