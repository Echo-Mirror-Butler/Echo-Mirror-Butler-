/**
 * health — Supabase Edge Function
 *
 * Public health-check: verifies DB connectivity and Stellar Horizon
 * reachability, and reports a simple aggregate status. Backs the /status page.
 */
import { createClient } from 'npm:@supabase/supabase-js@2'

const jsonHeaders = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Cache-Control': 'no-store',
}

function getEnv(name: string, fallback = '') {
  return Deno.env.get(name) ?? fallback
}

function horizonUrl() {
  const network = getEnv('STELLAR_NETWORK', 'testnet').toLowerCase()
  return network === 'mainnet' ? 'https://horizon.stellar.org' : 'https://horizon-testnet.stellar.org'
}

async function timed<T>(fn: () => Promise<T>): Promise<{ result: T | null; ms: number; error: string | null }> {
  const start = performance.now()
  try {
    const result = await fn()
    return { result, ms: Math.round(performance.now() - start), error: null }
  } catch (err) {
    return { result: null, ms: Math.round(performance.now() - start), error: err instanceof Error ? err.message : String(err) }
  }
}

async function checkDatabase() {
  const supabaseUrl = getEnv('SUPABASE_URL')
  const serviceRoleKey = getEnv('SUPABASE_SERVICE_ROLE_KEY')
  if (!supabaseUrl || !serviceRoleKey) {
    return { status: 'down' as const, latency_ms: 0, error: 'Missing SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY' }
  }
  const supabase = createClient(supabaseUrl, serviceRoleKey)
  const { ms, error } = await timed(async () => {
    const { error: queryError } = await supabase.from('profiles').select('id', { count: 'exact', head: true }).limit(1)
    if (queryError) throw new Error(queryError.message)
  })
  return { status: error ? ('down' as const) : ('up' as const), latency_ms: ms, error }
}

async function checkHorizon() {
  const { ms, error } = await timed(async () => {
    const controller = new AbortController()
    const timeout = setTimeout(() => controller.abort(), 5000)
    try {
      const res = await fetch(horizonUrl(), { signal: controller.signal })
      if (!res.ok) throw new Error(`Horizon responded with ${res.status}`)
    } finally {
      clearTimeout(timeout)
    }
  })
  return { status: error ? ('down' as const) : ('up' as const), latency_ms: ms, error }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: jsonHeaders })
  }

  const [database, stellar_horizon] = await Promise.all([checkDatabase(), checkHorizon()])

  const checks = { database, stellar_horizon }
  const allUp = Object.values(checks).every((check) => check.status === 'up')
  const anyDown = Object.values(checks).some((check) => check.status === 'down')
  const status = allUp ? 'operational' : anyDown ? 'degraded' : 'unknown'

  return new Response(
    JSON.stringify({
      status,
      checked_at: new Date().toISOString(),
      checks,
    }),
    { status: 200, headers: jsonHeaders },
  )
})
