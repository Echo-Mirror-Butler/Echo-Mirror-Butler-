import { Navigate, Route, Routes } from 'react-router-dom'
import { AppShell } from '../components/layout/app-shell'
import { SignInPanel } from '../components/auth/sign-in-panel'
import { LandingPage } from '../features/landing/LandingPage'
import { useAuth } from '../lib/auth-context'
import { WalletPage } from '../features/wallet/wallet-page'
import { LogsListPage } from '../features/logs/logs-list-page'
import { LogFormPage } from '../features/logs/log-form-page'
import { InsightsPage } from '../features/insights/insights-page'
import { AnalyticsPage } from '../features/analytics/analytics-page'
import { GlobalMirrorPage } from '../features/global-mirror/global-mirror-page'
import { DashboardPage } from '../features/dashboard/dashboard-page'
import { SettingsPage } from '../features/settings/settings-page'
import { ErrorBoundary } from '../components/error-boundary'
import NotFoundPage from '../features/shared/not-found-page'
import { SignupPage } from '../features/auth/pages/SignupPage'
import { ResetPasswordPage } from '../features/auth/pages/ResetPasswordPage'
import { UpdatePasswordPage } from '../features/auth/pages/UpdatePasswordPage'

function RequireAuth() {
  const { user, isLoading } = useAuth()

  if (isLoading) {
    return <div className="page-message">Loading session…</div>
  }

  if (!user) {
    return <Navigate to="/login" replace />
  }

  return (
    <ErrorBoundary>
      <AppShell />
    </ErrorBoundary>
  )
}

export function AppRouter() {
  const { user } = useAuth()

  return (
    <Routes>
      <Route
        path="/"
        element={user ? <Navigate to="/dashboard" replace /> : <LandingPage />}
      />
      <Route path="/login" element={user ? <Navigate to="/dashboard" replace /> : <SignInPanel />} />
      <Route path="/signup" element={user ? <Navigate to="/dashboard" replace /> : <SignupPage />} />
      <Route path="/reset-password" element={user ? <Navigate to="/dashboard" replace /> : <ResetPasswordPage />} />
      <Route path="/update-password" element={user ? <Navigate to="/dashboard" replace /> : <UpdatePasswordPage />} />

      <Route element={<RequireAuth />}>
        <Route path="/dashboard" element={<DashboardPage />} />
        <Route path="/wallet" element={<WalletPage />} />
        <Route path="/logs" element={<LogsListPage />} />
        <Route path="/logs/new" element={<LogFormPage mode="create" />} />
        <Route path="/logs/:id/edit" element={<LogFormPage mode="edit" />} />
        <Route path="/insights" element={<InsightsPage />} />
        <Route path="/analytics" element={<AnalyticsPage />} />
        <Route path="/global-mirror" element={<GlobalMirrorPage />} />
        <Route path="/settings" element={<SettingsPage />} />
      </Route>

      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  )
}
