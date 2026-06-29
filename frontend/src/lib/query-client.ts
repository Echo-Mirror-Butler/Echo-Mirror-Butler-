import { MutationCache, QueryCache, QueryClient } from '@tanstack/react-query'
import { getErrorMessage, generateErrorReferenceCode } from './error-reference'

function showQueryFailure(title: string, value: unknown) {
  if (typeof window === 'undefined') return

  window.dispatchEvent(
    new CustomEvent('echomirror:toast', {
      detail: {
        title,
        message: getErrorMessage(value),
        referenceCode: generateErrorReferenceCode(),
      },
    }),
  )
}

function showErrorToast(message: string) {
  const event = new CustomEvent('app:show-toast', {
    detail: { message, type: 'error' },
  })
  window.dispatchEvent(event)
}

export const queryClient = new QueryClient({
  queryCache: new QueryCache({
    onError: (error) => showQueryFailure('Could not load data', error),
  }),
  mutationCache: new MutationCache({
    onError: (error) => showQueryFailure('Could not save changes', error),
  }),
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
