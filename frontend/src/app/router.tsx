import React, { Suspense } from "react";
import { Navigate, Route, Routes } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { AppShell } from "../components/layout/app-shell";
import { SignInPanel } from "../components/auth/sign-in-panel";
import { LandingPage } from "../features/landing/LandingPage";
import { useAuth } from "../lib/auth-context";
import { ErrorBoundary } from "../components/error-boundary";
import NotFoundPage from "../features/shared/not-found-page";
import { SignupPage } from "../features/auth/pages/SignupPage";
import { ResetPasswordPage } from "../features/auth/pages/ResetPasswordPage";
import { UpdatePasswordPage } from "../features/auth/pages/UpdatePasswordPage";
import { supabase } from "../lib/supabase";
import { PageSkeleton } from "../components/layout/page-skeleton";

const WalletPage = React.lazy(() => import("../features/wallet/wallet-page").then(m => ({ default: m.WalletPage })));
const LogsListPage = React.lazy(() => import("../features/logs/logs-list-page").then(m => ({ default: m.LogsListPage })));
const LogFormPage = React.lazy(() => import("../features/logs/log-form-page").then(m => ({ default: m.LogFormPage })));
const LogDetailPage = React.lazy(() => import("../features/logs/log-detail-page").then(m => ({ default: m.LogDetailPage })));
const InsightsPage = React.lazy(() => import("../features/insights/insights-page").then(m => ({ default: m.InsightsPage })));
const AnalyticsPage = React.lazy(() => import("../features/analytics/analytics-page").then(m => ({ default: m.AnalyticsPage })));
const GlobalMirrorPage = React.lazy(() => import("../features/global-mirror/global-mirror-page").then(m => ({ default: m.GlobalMirrorPage })));
const DashboardPage = React.lazy(() => import("../features/dashboard/dashboard-page").then(m => ({ default: m.DashboardPage })));
const SettingsPage = React.lazy(() => import("../features/settings/settings-page").then(m => ({ default: m.SettingsPage })));
const OnboardingPage = React.lazy(() => import("../features/onboarding/onboarding-page").then(m => ({ default: m.OnboardingPage })));

function OnboardingGuard() {
  const { user, isLoading } = useAuth();

  if (isLoading) {
    return <div className="page-message">Loading session…</div>;
  }

  if (!user) {
    return <Navigate to="/login" replace />;
  }

  return <OnboardingPage />;
}

function RequireAuth() {
  const { user, isLoading } = useAuth();

  const logCountQuery = useQuery({
    queryKey: ["onboarding-check", user?.id],
    queryFn: async () => {
      const { count, error } = await supabase
        .from("log_entries")
        .select("id", { count: "exact", head: true })
        .eq("user_id", user!.id);
      if (error) return 1;
      return count ?? 0;
    },
    enabled: !!user && !user.user_metadata?.onboarding_completed,
    staleTime: 30_000,
  });

  if (isLoading) {
    return <div className="page-message">Loading session…</div>;
  }

  if (!user) {
    return (
      <Navigate
        to="/login"
        state={{ from: window.location.pathname }}
        replace
      />
    );
  }

  if (
    !user.user_metadata?.onboarding_completed &&
    logCountQuery.data === 0
  ) {
    return <Navigate to="/onboarding" replace />;
  }

  return (
    <ErrorBoundary>
      <AppShell />
    </ErrorBoundary>
  );
}

export function AppRouter() {
  const { user } = useAuth();

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
          element={
            user ? <Navigate to="/dashboard" replace /> : <ResetPasswordPage />
          }
        />
        <Route
          path="/update-password"
          element={
            user ? <Navigate to="/dashboard" replace /> : <UpdatePasswordPage />
          }
        />

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
  );
}
