import { isTestnet } from '../lib/stellar-config'

export function TestnetBadge() {
  if (!isTestnet) return null

  return (
    <span
      className="inline-flex items-center gap-1.5 rounded-full bg-amber-100 text-amber-800 border border-amber-300 px-2.5 py-0.5 text-xs font-semibold tracking-wide select-none"
      title="You are on the Stellar Testnet. Tokens have no real-world value."
      aria-label="Stellar Testnet — no real funds"
    >
      <span className="relative flex h-2 w-2" aria-hidden="true">
        <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-amber-400 opacity-75" />
        <span className="relative inline-flex rounded-full h-2 w-2 bg-amber-500" />
      </span>
      TESTNET
    </span>
  )
}

export default TestnetBadge
