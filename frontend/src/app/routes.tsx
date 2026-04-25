import { createBrowserRouter } from 'react-router-dom'
import { LoginPage } from '@/features/auth/pages/LoginPage'
import { SignupPage } from '@/features/auth/pages/SignupPage'
import { ResetPasswordPage } from '@/features/auth/pages/ResetPasswordPage'
import { UpdatePasswordPage } from '@/features/auth/pages/UpdatePasswordPage'
import { DashboardPage } from '@/features/dashboard/pages/DashboardPage'
import { ProtectedRoute } from '@/components/ProtectedRoute'

// Landing page
const HomePage = () => (
  <div className="min-h-screen flex items-center justify-center bg-gray-50">
    <div className="text-center">
      <h1 className="text-4xl font-bold text-primary mb-4">EchoMirror Butler</h1>
      <p className="text-gray-600">Your Personal Growth Assistant</p>
    </div>
  </div>
)

export const router = createBrowserRouter([
  {
    path: '/',
    element: <HomePage />,
  },
  {
    path: '/login',
    element: <LoginPage />,
  },
  {
    path: '/signup',
    element: <SignupPage />,
  },
  {
    path: '/reset-password',
    element: <ResetPasswordPage />,
  },
  {
    path: '/update-password',
    element: <UpdatePasswordPage />,
  },
  {
    path: '/dashboard',
    element: (
      <ProtectedRoute>
        <DashboardPage />
      </ProtectedRoute>
    ),
  },
])
