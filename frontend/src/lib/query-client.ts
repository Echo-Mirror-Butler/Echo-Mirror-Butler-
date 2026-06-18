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
    },
    mutations: {
      retry: 0,
    },
  },
})
