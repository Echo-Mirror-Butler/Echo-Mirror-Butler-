import React from 'react'
import ReactDOM from 'react-dom/client'
import { AppProviders } from './app/providers'
import { AppRouter } from './app/router'
import { validateEnv } from './lib/env-validation'
import './styles.css'

// Fail fast with a clear message if required env vars are absent or invalid.
validateEnv()

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <AppProviders>
      <AppRouter />
    </AppProviders>
  </React.StrictMode>,
)
