import { lazy, Suspense } from 'react'
import { Navigate, Route, Routes } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { AppShell } from '../components/layout/app-shell'
import { SignInPanel } from '../components/auth/sign-in-panel'
import { LandingPage } from '../features/landing/LandingPage'
import { SignupPage } from '../features/auth/pages/SignupPage'
import { ResetPasswordPage } from '../features/auth/pages/ResetPasswordPage'
import { UpdatePasswordPage } from '../features/auth/pages/UpdatePasswordPage'
import { ErrorBoundary } from '../components/error-boundary'
import { useAuth } from '../lib/auth-context'
import { supabase } from '../lib/supabase'

// Lazy-loaded feature pages — only downloaded when the route is first visited
const DashboardPage = lazy(() =>
  import('../features/dashboard/dashboard-page').then((m) => ({ default: m.DashboardPage })),
)
const WalletPage = lazy(() =>
  import('../features/wallet/wallet-page').then((m) => ({ default: m.WalletPage })),
)
const LogsListPage = lazy(() =>
  import('../features/logs/logs-list-page').then((m) => ({ default: m.LogsListPage })),
)
const LogFormPage = lazy(() =>
  import('../features/logs/log-form-page').then((m) => ({ default: m.LogFormPage })),
)
const LogDetailPage = lazy(() =>
  import('../features/logs/log-detail-page').then((m) => ({ default: m.LogDetailPage })),
)
const InsightsPage = lazy(() =>
  import('../features/insights/insights-page').then((m) => ({ default: m.InsightsPage })),
)
const AnalyticsPage = lazy(() =>
  import('../features/analytics/analytics-page').then((m) => ({ default: m.AnalyticsPage })),
)
const GlobalMirrorPage = lazy(() =>
  import('../features/global-mirror/global-mirror-page').then((m) => ({ default: m.GlobalMirrorPage })),
)
const SettingsPage = lazy(() =>
  import('../features/settings/settings-page').then((m) => ({ default: m.SettingsPage })),
)
const OnboardingPage = lazy(() =>
  import('../features/onboarding/onboarding-page').then((m) => ({ default: m.OnboardingPage })),
)
const NotFoundPage = lazy(() => import('../features/shared/not-found-page'))

function PageSkeleton() {
  return (
    <div
      aria-busy="true"
      aria-label="Loading page…"
      style={{
        minHeight: '100vh',
        width: '100%',
        background: 'var(--bg-page, var(--surface, #f5f5f5))',
        backgroundSize: '400% 100%',
        animation: 'page-skeleton-shimmer 1.6s ease-in-out infinite',
      }}
    >
      <style>{`
        @keyframes page-skeleton-shimmer {
          0%   { opacity: 1; }
          50%  { opacity: 0.5; }
          100% { opacity: 1; }
        }
      `}</style>
    </div>
  )
}

function OnboardingGuard() {
  const { user, isLoading } = useAuth()

  if (isLoading) {
    return <div className="page-message">Loading session…</div>
  }

  if (!user) {
    return <Navigate to="/login" replace />
  }

  return (
    <Suspense fallback={<PageSkeleton />}>
      <OnboardingPage />
    </Suspense>
  )
}

function RequireAuth() {
  const { user, isLoading } = useAuth()

  const logCountQuery = useQuery({
    queryKey: ['onboarding-check', user?.id],
    queryFn: async () => {
      const { count, error } = await supabase
        .from('log_entries')
        .select('id', { count: 'exact', head: true })
        .eq('user_id', user!.id)
      if (error) return 1
      return count ?? 0
    },
    enabled: !!user && !user.user_metadata?.onboarding_completed,
    staleTime: 30_000,
  })

  if (isLoading) {
    return <div className="page-message">Loading session…</div>
  }

  if (!user) {
    return (
      <Navigate
        to="/login"
        state={{ from: window.location.pathname }}
        replace
      />
    )
  }

  if (!user.user_metadata?.onboarding_completed && logCountQuery.data === 0) {
    return <Navigate to="/onboarding" replace />
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
    <Suspense fallback={<PageSkeleton />}>
      <Routes>
        <Route
          path="/"
          element={user ? <Navigate to="/dashboard" replace /> : <LandingPage />}
        />
        <Route
          path="/login"
          element={user ? <Navigate to="/dashboard" replace /> : <SignInPanel />}
        />
        <Route
          path="/signup"
          element={user ? <Navigate to="/dashboard" replace /> : <SignupPage />}
        />
        <Route
          path="/reset-password"
          element={user ? <Navigate to="/dashboard" replace /> : <ResetPasswordPage />}
        />
        <Route path="/update-password" element={<UpdatePasswordPage />} />

        <Route
          path="/onboarding"
          element={user ? <OnboardingGuard /> : <Navigate to="/login" replace />}
        />

        <Route element={<RequireAuth />}>
          <Route path="/dashboard" element={<DashboardPage />} />
          <Route path="/wallet" element={<WalletPage />} />
          <Route path="/logs" element={<LogsListPage />} />
          <Route path="/logs/new" element={<LogFormPage mode="create" />} />
          <Route path="/logs/:id" element={<LogDetailPage />} />
          <Route path="/logs/:id/edit" element={<LogFormPage mode="edit" />} />
          <Route path="/insights" element={<InsightsPage />} />
          <Route path="/analytics" element={<AnalyticsPage />} />
          <Route path="/global-mirror" element={<GlobalMirrorPage />} />
          <Route path="/settings" element={<SettingsPage />} />
        </Route>

        <Route path="*" element={<NotFoundPage />} />
      </Routes>
    </Suspense>
  )
}
