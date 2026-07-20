import { useQuery } from '@tanstack/react-query'
import { stellarConfig } from './stellar-config'

type HorizonBalance = {
  asset_type: string
  asset_code?: string
  balance: string
}

export type WalletBalancesResult = {
  xlm: string
  echo: string
  notFunded: boolean
  fetchedAt: number
}

async function fetchHorizonBalances(publicKey: string): Promise<WalletBalancesResult> {
  const res = await fetch(`${stellarConfig.horizonUrl}/accounts/${publicKey}`)
  if (res.status === 404) {
    return { xlm: '0', echo: '0', notFunded: true, fetchedAt: Date.now() }
  }
  if (!res.ok) {
    throw new Error(`Horizon error: ${res.status}`)
  }
  const account = (await res.json()) as { balances: HorizonBalance[] }
  const balances = account.balances ?? []
  const xlm = balances.find((b) => b.asset_type === 'native')?.balance ?? '0'
  const echo = balances.find((b) => b.asset_code === 'ECHO')?.balance ?? '0'
  return { xlm, echo, notFunded: false, fetchedAt: Date.now() }
}

export function useWalletBalances(publicKey: string | null | undefined) {
  return useQuery({
    queryKey: ['horizon-balances', publicKey],
    queryFn: () => fetchHorizonBalances(publicKey!),
    enabled: Boolean(publicKey),
    refetchInterval: 30_000,
  })
}
