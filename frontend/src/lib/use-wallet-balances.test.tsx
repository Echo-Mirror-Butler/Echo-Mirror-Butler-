import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { renderHook } from '@testing-library/react'
import { waitFor } from '@testing-library/dom'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { useWalletBalances } from './use-wallet-balances'
import { stellarConfig } from './stellar-config'

const PUBLIC_KEY = 'GABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCD'

function renderWithClient() {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  })
  return renderHook(() => useWalletBalances(PUBLIC_KEY), {
    wrapper: ({ children }) => (
      <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
    ),
  })
}

describe('useWalletBalances', () => {
  beforeEach(() => {
    vi.stubGlobal(
      'fetch',
      vi.fn(() =>
        Promise.resolve({
          ok: true,
          status: 200,
          json: () => Promise.resolve({ balances: [] }),
        }),
      ),
    )
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('requests balances from the configured Horizon URL, not a hardcoded host', async () => {
    const { result } = renderWithClient()

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(fetch).toHaveBeenCalledWith(`${stellarConfig.horizonUrl}/accounts/${PUBLIC_KEY}`)
  })

  it('respects VITE_STELLAR_HORIZON_URL overrides', async () => {
    vi.stubEnv('VITE_STELLAR_HORIZON_URL', 'https://custom-horizon.example.com')
    vi.resetModules()

    const { useWalletBalances: useWalletBalancesWithOverride } = await import('./use-wallet-balances')

    const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    const { result } = renderHook(() => useWalletBalancesWithOverride(PUBLIC_KEY), {
      wrapper: ({ children }) => (
        <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
      ),
    })

    await waitFor(() => expect(result.current.isSuccess).toBe(true))

    expect(fetch).toHaveBeenCalledWith(
      `https://custom-horizon.example.com/accounts/${PUBLIC_KEY}`,
    )

    vi.unstubAllEnvs()
  })
})
