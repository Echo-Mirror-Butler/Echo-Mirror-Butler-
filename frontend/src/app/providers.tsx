import { type ReactNode } from 'react'
import { QueryClientProvider } from '@tanstack/react-query'
import { BrowserRouter } from 'react-router-dom'
import { AuthProvider } from '../lib/auth-context'
import { ToastProvider } from '../lib/use-toast'
import { queryClient } from '../lib/query-client'

export function AppProviders({ children }: { children: ReactNode }) {
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <BrowserRouter>
          <ToastProvider>{children}</ToastProvider>
        </BrowserRouter>
      </AuthProvider>
    </QueryClientProvider>
  )
}
