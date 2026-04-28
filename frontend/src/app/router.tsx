import { Navigate, Route, Routes } from 'react-router-dom'
import { AppShell } from '../components/layout/app-shell'
import { SignInPanel } from '../components/auth/sign-in-panel'
import { useAuth } from '../lib/auth-context'
import { DashboardPage } from '../features/dashboard/pages/DashboardPage'
import { WalletPage } from '../features/wallet/wallet-page'
import { LogsListPage } from '../features/logs/logs-list-page'
import { LogFormPage } from '../features/logs/log-form-page'
import { InsightsPage } from '../features/insights/insights-page'

function RequireAuth() {
  const { user, isLoading } = useAuth()

  if (isLoading) {
    return <div className="page-message">Loading session…</div>
  }

  if (!user) {
    return <SignInPanel />
  }

  return <AppShell />
}

export function AppRouter() {
  return (
    <Routes>
      <Route element={<RequireAuth />}>
        <Route path="/" element={<Navigate to="/dashboard" replace />} />
        <Route path="/dashboard" element={<DashboardPage />} />
        <Route path="/wallet" element={<WalletPage />} />
        <Route path="/logs" element={<LogsListPage />} />
        <Route path="/logs/new" element={<LogFormPage mode="create" />} />
        <Route path="/logs/:id/edit" element={<LogFormPage mode="edit" />} />
        <Route path="/insights" element={<InsightsPage />} />
      </Route>
    </Routes>
  )
}
