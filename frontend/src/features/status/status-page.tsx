import { useQuery } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'

type CheckResult = {
  status: 'up' | 'down'
  latency_ms: number
  error: string | null
}

type HealthResponse = {
  status: 'operational' | 'degraded' | 'unknown'
  checked_at: string
  checks: Record<string, CheckResult>
}

async function fetchHealth(): Promise<HealthResponse> {
  const { data, error } = await supabase.functions.invoke<HealthResponse>('health')
  if (error) throw error
  if (!data) throw new Error('Empty health response')
  return data
}

const STATUS_LABEL: Record<HealthResponse['status'], string> = {
  operational: 'All systems operational',
  degraded: 'Degraded — some checks are failing',
  unknown: 'Unable to determine status',
}

const STATUS_COLOR: Record<HealthResponse['status'], string> = {
  operational: 'var(--success, #1a9e5c)',
  degraded: 'var(--danger, #d34b32)',
  unknown: 'var(--muted, #888)',
}

const CHECK_LABEL: Record<string, string> = {
  database: 'Database',
  stellar_horizon: 'Stellar Horizon',
}

export default function StatusPage() {
  const { data, error, isLoading, isFetching, refetch, dataUpdatedAt } = useQuery({
    queryKey: ['status-health'],
    queryFn: fetchHealth,
    refetchInterval: 30_000,
    retry: false,
  })

  const status = error ? 'unknown' : data?.status ?? 'unknown'

  return (
    <div style={{ maxWidth: 560, margin: '3rem auto', padding: '0 1rem' }}>
      <div className="card" style={{ padding: '1.5rem' }}>
        <h1 style={{ marginTop: 0 }}>EchoMirror Status</h1>

        <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem', margin: '1rem 0' }}>
          <span
            aria-hidden="true"
            style={{
              width: 12,
              height: 12,
              borderRadius: '50%',
              background: STATUS_COLOR[status],
              display: 'inline-block',
              flexShrink: 0,
            }}
          />
          <strong style={{ fontSize: '1.1rem' }}>
            {isLoading ? 'Checking…' : STATUS_LABEL[status]}
          </strong>
        </div>

        {error ? (
          <p className="error-text">Could not reach the health-check endpoint.</p>
        ) : null}

        {data ? (
          <table style={{ width: '100%', borderCollapse: 'collapse', marginTop: '1rem' }}>
            <thead>
              <tr>
                <th align="left" style={{ padding: '0.4rem 0', borderBottom: '1px solid var(--line)' }}>Component</th>
                <th align="left" style={{ padding: '0.4rem 0', borderBottom: '1px solid var(--line)' }}>Status</th>
                <th align="left" style={{ padding: '0.4rem 0', borderBottom: '1px solid var(--line)' }}>Latency</th>
              </tr>
            </thead>
            <tbody>
              {Object.entries(data.checks).map(([key, check]) => (
                <tr key={key}>
                  <td style={{ padding: '0.4rem 0' }}>{CHECK_LABEL[key] ?? key}</td>
                  <td style={{ padding: '0.4rem 0', color: check.status === 'up' ? STATUS_COLOR.operational : STATUS_COLOR.degraded }}>
                    {check.status === 'up' ? 'Up' : `Down${check.error ? ` — ${check.error}` : ''}`}
                  </td>
                  <td style={{ padding: '0.4rem 0' }}>{check.latency_ms} ms</td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : null}

        <p className="muted" style={{ fontSize: '0.8rem', marginTop: '1.5rem' }}>
          {dataUpdatedAt ? `Last checked ${new Date(dataUpdatedAt).toLocaleTimeString()}` : ''}
          {' · '}
          <button
            type="button"
            onClick={() => void refetch()}
            disabled={isFetching}
            style={{ background: 'none', border: 'none', color: 'var(--brand)', cursor: 'pointer', padding: 0, font: 'inherit' }}
          >
            {isFetching ? 'Refreshing…' : 'Refresh now'}
          </button>
          {' · auto-refreshes every 30s'}
        </p>
      </div>
    </div>
  )
}
