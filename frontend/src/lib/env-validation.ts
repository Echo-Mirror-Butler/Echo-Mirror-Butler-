export function validateEnv(): void {
  const required: Array<{ key: string; desc: string }> = [
    { key: 'VITE_STELLAR_NETWORK', desc: 'Must be "testnet" or "mainnet"' },
    { key: 'VITE_SUPABASE_URL', desc: 'Your Supabase project URL' },
    { key: 'VITE_SUPABASE_ANON_KEY', desc: 'Your Supabase anon public key' },
  ]

  const missing = required.filter(({ key }) => !import.meta.env[key])

  if (missing.length > 0) {
    const details = missing.map(({ key, desc }) => `  • ${key}  →  ${desc}`).join('\n')
    throw new Error(
      `\n\n🚨 Missing required environment variables:\n\n${details}\n\n` +
      `Copy frontend/.env.example → frontend/.env.local, fill in the values, and restart.\n`
    )
  }

  const network = import.meta.env.VITE_STELLAR_NETWORK as string
  if (!['testnet', 'mainnet'].includes(network)) {
    throw new Error(
      `🚨 VITE_STELLAR_NETWORK="${network}" is invalid.\n` +
      `Allowed values: "testnet" or "mainnet".\n` +
      `Update frontend/.env.local and restart.`
    )
  }
}
