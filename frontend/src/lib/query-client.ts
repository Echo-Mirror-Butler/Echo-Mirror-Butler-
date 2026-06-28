import { QueryClient } from '@tanstack/react-query'

function showErrorToast(message: string) {
  const event = new CustomEvent('app:show-toast', {
    detail: { message, type: 'error' },
  })
  window.dispatchEvent(event)
}

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 1,
      refetchOnWindowFocus: false,
      staleTime: 10_000,
      onError: (error) => {
        console.error('Query error:', error)
        const message = error instanceof Error ? error.message : 'An error occurred'
        showErrorToast(message)
      },
    },
    mutations: {
      retry: 0,
      onError: (error) => {
        console.error('Mutation error:', error)
        const message = error instanceof Error ? error.message : 'An error occurred'
        showErrorToast(message)
      },
    },
  },
})
