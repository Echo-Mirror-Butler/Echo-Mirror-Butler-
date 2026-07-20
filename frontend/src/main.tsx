import React from 'react'
import ReactDOM from 'react-dom/client'
import { AppProviders } from './app/providers'
import { AppRouter } from './app/router'
import { validateEnv } from './lib/env-validation'
import { initializeGlobalErrorHandler } from './lib/global-error-handler'
import './styles.css'

validateEnv()
initializeGlobalErrorHandler()

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <AppProviders>
      <AppRouter />
    </AppProviders>
  </React.StrictMode>,
)
