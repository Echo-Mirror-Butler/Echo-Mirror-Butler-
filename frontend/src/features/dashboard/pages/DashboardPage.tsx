import { useNavigate } from 'react-router-dom'
import { useAuthStore } from '@/features/auth/store/authStore'
import { Button } from '@/components/Button'
import { toDateInputValue } from '@/lib/date'

export function DashboardPage() {
  const navigate = useNavigate()
  const { user, signOut } = useAuthStore()

  const handleSignOut = async () => {
    await signOut()
    navigate('/login')
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 py-4 flex justify-between items-center">
          <h1 className="text-2xl font-bold text-primary">EchoMirror Dashboard</h1>
          <div className="flex items-center gap-4">
            <span className="text-gray-600">{user?.email}</span>
            <Button variant="outline" onClick={handleSignOut}>
              Sign Out
            </Button>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 py-8">
        <div className="bg-white rounded-lg shadow p-6">
          <h2 className="text-xl font-semibold mb-4">Welcome to EchoMirror</h2>
          <p className="text-gray-600">
            This is your personal dashboard. More features coming soon.
          </p>
          <div className="mt-6">
            <Button
              onClick={() => {
                const today = toDateInputValue(new Date())
                navigate(`/logs/new?date=${today}`)
              }}
              className="w-full"
            >
              Log Today's Mood
            </Button>
          </div>
        </div>
      </main>
    </div>
  )
}
