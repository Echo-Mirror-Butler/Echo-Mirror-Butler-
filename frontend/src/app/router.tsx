import { Navigate, Route, Routes } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { AppShell } from "../components/layout/app-shell";
import { SignInPanel } from "../components/auth/sign-in-panel";
import { LandingPage } from "../features/landing/LandingPage";
import { useAuth } from "../lib/auth-context";
import { WalletPage } from "../features/wallet/wallet-page";
import { LogsListPage } from "../features/logs/logs-list-page";
import { LogFormPage } from "../features/logs/log-form-page";
import { InsightsPage } from "../features/insights/insights-page";
import { AnalyticsPage } from "../features/analytics/analytics-page";
import { GlobalMirrorPage } from "../features/global-mirror/global-mirror-page";
import { DashboardPage } from "../features/dashboard/dashboard-page";
import { SettingsPage } from "../features/settings/settings-page";
import { ErrorBoundary } from "../components/error-boundary";
import NotFoundPage from "../features/shared/not-found-page";
import { SignupPage } from "../features/auth/pages/SignupPage";
import { ResetPasswordPage } from "../features/auth/pages/ResetPasswordPage";
import { UpdatePasswordPage } from "../features/auth/pages/UpdatePasswordPage";
import { OnboardingPage } from "../features/onboarding/onboarding-page";
import { supabase } from "../lib/supabase";

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
        <Route path="/logs/:id/edit" element={<LogFormPage mode="edit" />} />
        <Route path="/insights" element={<InsightsPage />} />
        <Route path="/analytics" element={<AnalyticsPage />} />
        <Route path="/global-mirror" element={<GlobalMirrorPage />} />
        <Route path="/settings" element={<SettingsPage />} />
      </Route>

      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  );
}
