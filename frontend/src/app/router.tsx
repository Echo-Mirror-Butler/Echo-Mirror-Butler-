import { Navigate, Route, Routes } from 'react-router-dom'
import { AppShell } from '../components/layout/app-shell'
import { SignInPanel } from '../components/auth/sign-in-panel'
import { useAuth } from '../lib/auth-context'
import { WalletPage } from '../features/wallet/wallet-page'
import { LogsListPage } from '../features/logs/logs-list-page'
import { LogFormPage } from '../features/logs/log-form-page'
import { InsightsPage } from '../features/insights/insights-page'
import { PlaceholderPage } from '../features/shared/placeholder-page'
import { AnalyticsPage } from '../features/analytics/analytics-page'

function RequireAuth() {
  const { user, isLoading } = useAuth()

  if (isLoading) {
    return <div className="page-message">Loading session…</div>
  }

  if (!user) {
    return <Navigate to="/login" replace />
  }

  return <AppShell />
}

export function AppRouter() {
  const { user } = useAuth()

  return (
    <Routes>
      <Route path="/login" element={user ? <Navigate to="/dashboard" replace /> : <SignInPanel />} />

      <Route element={<RequireAuth />}>
        <Route path="/" element={<Navigate to="/dashboard" replace />} />
        <Route
          path="/dashboard"
          element={
            <PlaceholderPage
              title="Dashboard"
              description="Overview widgets will land here once connected to live metrics."
            />
          }
        />
        <Route path="/wallet" element={<WalletPage />} />
        <Route path="/logs" element={<LogsListPage />} />
        <Route path="/logs/new" element={<LogFormPage mode="create" />} />
        <Route path="/logs/:id/edit" element={<LogFormPage mode="edit" />} />
        <Route path="/insights" element={<InsightsPage />} />
        <Route path="/analytics" element={<AnalyticsPage />} />
        <Route
          path="/global-mirror"
          element={
            <PlaceholderPage
              title="Global Mirror"
              description="Community mirror feed and world mood layers are coming next."
            />
          }
        />
        <Route
          path="/settings"
          element={
            <PlaceholderPage
              title="Settings"
              description="Profile, privacy, and app preference controls live here."
            />
          }
        />
      </Route>

      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}
