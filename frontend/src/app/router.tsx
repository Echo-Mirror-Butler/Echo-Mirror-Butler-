import { Navigate, Route, Routes } from 'react-router-dom'
import { AppShell } from '../components/layout/app-shell'
import { LandingPage } from '../features/landing/LandingPage'
import { SignInPanel } from '../components/auth/sign-in-panel'
import { useAuth } from '../lib/auth-context'
import { DashboardPage } from '../features/dashboard/pages/DashboardPage'
import { WalletPage } from '../features/wallet/wallet-page'
import { LogsListPage } from '../features/logs/logs-list-page'
import { LogFormPage } from '../features/logs/log-form-page'
import { InsightsPage } from '../features/insights/insights-page'
import { LoginPage } from '../features/auth/pages/LoginPage'

export function AppRouter() {
  const { user, isLoading } = useAuth()

  if (isLoading) {
    return <div className="page-message">Loading session…</div>
  }

  if (!user) {
    return (
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="*" element={<LandingPage />} />
      </Routes>
    )
  }

  return (
    <Routes>
      <Route element={<AppShell />}>
        <Route path="/dashboard" element={<DashboardPage />} />
        <Route path="/wallet" element={<WalletPage />} />
        <Route path="/logs" element={<LogsListPage />} />
        <Route path="/logs/new" element={<LogFormPage mode="create" />} />
        <Route path="/logs/:id/edit" element={<LogFormPage mode="edit" />} />
        <Route path="/insights" element={<InsightsPage />} />
        <Route path="*" element={<Navigate to="/dashboard" replace />} />
      </Route>
    </Routes>
  )
}
