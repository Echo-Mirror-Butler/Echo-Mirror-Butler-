import { useEffect } from 'react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { RouterProvider } from 'react-router-dom'
import { router } from './routes'
import { useAuthStore } from '@/features/auth/store/authStore'
import './index.css'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5, // 5 minutes
      retry: 1,
    },
  },
})

function App() {
  const initialize = useAuthStore((state) => state.initialize)

  useEffect(() => {
    const unsubscribe = initialize()
    return () => {
      if (unsubscribe) unsubscribe()
    }
  }, [initialize])

  return (
    <QueryClientProvider client={queryClient}>
      <RouterProvider router={router} />
    </QueryClientProvider>
  )
}

export default App
