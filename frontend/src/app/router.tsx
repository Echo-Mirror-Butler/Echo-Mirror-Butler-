import type { ReactNode } from "react";
import { Navigate, Route, Routes } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { AppShell } from "../components/layout/app-shell";
import { SignInPanel } from "../components/auth/sign-in-panel";
import { LandingPage } from "../features/landing/LandingPage";
import { useAuth } from "../lib/auth-context";
import { WalletPage } from "../features/wallet/wallet-page";
import { LogsListPage } from "../features/logs/logs-list-page";
import { LogFormPage } from "../features/logs/log-form-page";
import { LogDetailPage } from "../features/logs/log-detail-page";
import { InsightsPage } from "../features/insights/insights-page";
import { AnalyticsPage } from "../features/analytics/analytics-page";
import { GlobalMirrorPage } from "../features/global-mirror/global-mirror-page";
import { DashboardPage } from "../features/dashboard/dashboard-page";
import { SettingsPage } from "../features/settings/settings-page";
import { RouteErrorBoundary } from "../components/error-boundary";
import NotFoundPage from "../features/shared/not-found-page";
import { SignupPage } from "../features/auth/pages/SignupPage";
import { ResetPasswordPage } from "../features/auth/pages/ResetPasswordPage";
import { UpdatePasswordPage } from "../features/auth/pages/UpdatePasswordPage";
import { OnboardingPage } from "../features/onboarding/onboarding-page";
import { supabase } from "../lib/supabase";

function withRouteBoundary(routeName: string, element: ReactNode) {
  return <RouteErrorBoundary routeName={routeName}>{element}</RouteErrorBoundary>;
}

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

  return <AppShell />;
}

export function AppRouter() {
  const { user } = useAuth();

  return (
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
        element={<UpdatePasswordPage />}
      />

      <Route
        path="/onboarding"
        element={user ? withRouteBoundary("Onboarding", <OnboardingGuard />) : <Navigate to="/login" replace />}
      />

      <Route element={<RequireAuth />}>
        <Route path="/dashboard" element={withRouteBoundary("Dashboard", <DashboardPage />)} />
        <Route path="/wallet" element={withRouteBoundary("Wallet", <WalletPage />)} />
        <Route path="/logs" element={withRouteBoundary("Logs", <LogsListPage />)} />
        <Route path="/logs/new" element={withRouteBoundary("New Log", <LogFormPage mode="create" />)} />
        <Route path="/logs/:id/edit" element={withRouteBoundary("Edit Log", <LogFormPage mode="edit" />)} />
        <Route path="/insights" element={withRouteBoundary("AI Insights", <InsightsPage />)} />
        <Route path="/analytics" element={withRouteBoundary("Analytics", <AnalyticsPage />)} />
        <Route path="/global-mirror" element={withRouteBoundary("Global Mirror", <GlobalMirrorPage />)} />
        <Route path="/settings" element={withRouteBoundary("Settings", <SettingsPage />)} />
      </Route>

      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  );
}
