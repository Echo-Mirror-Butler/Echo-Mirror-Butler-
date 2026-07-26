import { useEffect, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'
import { formatDateTime } from '../../lib/date'

type ReferralStats = {
  code: string
  total_referrals: number
  completed_referrals: number
}

type ReferralRecord = {
  id: string
  referrer_id: string
  referred_id: string
  referral_code: string
  completed: boolean
  created_at: string
}

function Skeleton() {
  return (
    <div className="card animate-stagger">
      {[1, 2, 3].map((i) => (
        <div key={i} style={{ height: 60, borderRadius: '12px', background: 'var(--line)', marginBottom: '1rem', animation: 'pulse 1.5s ease-in-out infinite' }} />
      ))}
    </div>
  )
}

export function ReferralsPage() {
  const { user } = useAuth()
  const queryClient = useQueryClient()
  const [copied, setCopied] = useState(false)
  const [shareError, setShareError] = useState<string | null>(null)

  const statsQuery = useQuery({
    queryKey: ['referral-stats', user?.id],
    queryFn: async (): Promise<ReferralStats> => {
      const { data, error } = await supabase.rpc('get_referral_stats', {
        p_user_id: user!.id,
      })
      if (error) throw error
      return data as ReferralStats
    },
    enabled: Boolean(user?.id),
  })

  const historyQuery = useQuery({
    queryKey: ['referral-history', user?.id],
    queryFn: async (): Promise<ReferralRecord[]> => {
      const { data, error } = await supabase
        .from('referrals')
        .select('*')
        .eq('referrer_id', user!.id)
        .order('created_at', { ascending: false })
        .limit(50)
      if (error) throw error
      return (data ?? []) as ReferralRecord[]
    },
    enabled: Boolean(user?.id),
  })

  const inviteUrl = statsQuery.data
    ? `${window.location.origin}/signup?ref=${statsQuery.data.code}`
    : ''

  const handleCopy = async () => {
    if (!inviteUrl) return
    try {
      await navigator.clipboard.writeText(inviteUrl)
      setCopied(true)
      window.setTimeout(() => setCopied(false), 2000)
    } catch {
      setShareError('Failed to copy to clipboard')
    }
  }

  const handleShare = async () => {
    if (!inviteUrl) return
    setShareError(null)

    if (navigator.share) {
      try {
        await navigator.share({
          title: 'Join EchoMirror',
          text: 'Track your mood and earn ECHO tokens with me!',
          url: inviteUrl,
        })
      } catch (err) {
        if ((err as Error).name !== 'AbortError') {
          setShareError('Share cancelled')
        }
      }
    } else {
      await handleCopy()
    }
  }

  if (statsQuery.isLoading) return <Skeleton />

  if (statsQuery.isError) {
    return (
      <section className="card full-width">
        <p className="muted">Failed to load referral data.</p>
        <button type="button" onClick={() => statsQuery.refetch()} style={{ marginTop: '0.5rem' }}>
          Retry
        </button>
      </section>
    )
  }

  const stats = statsQuery.data!
  const history = historyQuery.data ?? []

  return (
    <div className="page-wrap animate-stagger" style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
      <h1 style={{ margin: 0 }}>Invite Friends</h1>

      <section className="card">
        <h2 style={{ marginTop: 0 }}>Your Referral Code</h2>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '1rem',
            padding: '1rem',
            background: 'var(--surface-soft)',
            borderRadius: '12px',
            border: '1px solid var(--line)',
            flexWrap: 'wrap',
          }}
        >
          <code
            style={{
              fontSize: '1.5rem',
              fontWeight: 700,
              fontFamily: "'Space Grotesk', monospace",
              color: 'var(--brand)',
              letterSpacing: '0.1em',
            }}
          >
            {stats.code}
          </code>
          <div style={{ display: 'flex', gap: '0.5rem', flex: 1, justifyContent: 'flex-end' }}>
            <button type="button" onClick={() => void handleCopy()}>
              {copied ? 'Copied!' : 'Copy Link'}
            </button>
            <button type="button" className="secondary" onClick={() => void handleShare()}>
              Share
            </button>
          </div>
        </div>
        <p className="muted" style={{ marginTop: '0.75rem', fontSize: '0.85rem' }}>
          Share this link with friends. When they sign up and complete onboarding, you both earn bonus ECHO.
        </p>
        {shareError && <p className="error-text" style={{ marginTop: '0.5rem' }}>{shareError}</p>}
      </section>

      <section className="card">
        <h2 style={{ marginTop: 0 }}>Referral Stats</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: '1rem' }}>
          <div
            style={{
              padding: '1rem',
              background: 'var(--surface-soft)',
              borderRadius: '12px',
              textAlign: 'center',
              border: '1px solid var(--line)',
            }}
          >
            <span style={{ fontSize: '2rem', fontWeight: 700, color: 'var(--brand)' }}>
              {stats.total_referrals}
            </span>
            <p className="muted" style={{ margin: '0.25rem 0 0', fontSize: '0.85rem' }}>Total Referrals</p>
          </div>
          <div
            style={{
              padding: '1rem',
              background: 'var(--surface-soft)',
              borderRadius: '12px',
              textAlign: 'center',
              border: '1px solid var(--line)',
            }}
          >
            <span style={{ fontSize: '2rem', fontWeight: 700, color: 'var(--success)' }}>
              {stats.completed_referrals}
            </span>
            <p className="muted" style={{ margin: '0.25rem 0 0', fontSize: '0.85rem' }}>Completed</p>
          </div>
          <div
            style={{
              padding: '1rem',
              background: 'var(--surface-soft)',
              borderRadius: '12px',
              textAlign: 'center',
              border: '1px solid var(--line)',
            }}
          >
            <span style={{ fontSize: '2rem', fontWeight: 700, color: 'var(--brand)' }}>
              +{(stats.completed_referrals * 25)}
            </span>
            <p className="muted" style={{ margin: '0.25rem 0 0', fontSize: '0.85rem' }}>ECHO Earned</p>
          </div>
        </div>
      </section>

      <section className="card">
        <h2 style={{ marginTop: 0 }}>Referral History</h2>
        {historyQuery.isLoading ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
            {[1, 2, 3].map((i) => (
              <div key={i} style={{ height: 48, borderRadius: '8px', background: 'var(--line)', animation: 'pulse 1.5s ease-in-out infinite' }} />
            ))}
          </div>
        ) : history.length === 0 ? (
          <p className="muted" style={{ padding: '1rem 0', textAlign: 'center' }}>
            No referrals yet. Share your code to get started!
          </p>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
            {history.map((record) => (
              <div
                key={record.id}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '0.65rem 0.85rem',
                  borderRadius: '10px',
                  background: 'var(--surface-soft)',
                  border: '1px solid var(--line)',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                  <span style={{ fontSize: '1.1rem' }}>
                    {record.completed ? '✅' : '⏳'}
                  </span>
                  <span style={{ fontSize: '0.85rem', color: 'var(--muted)' }}>
                    {record.referred_id.slice(0, 8)}...
                  </span>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                  <span
                    className={record.completed ? 'chip active' : 'chip'}
                    style={{ fontSize: '0.75rem' }}
                  >
                    {record.completed ? 'Completed' : 'Pending'}
                  </span>
                  <span style={{ fontSize: '0.75rem', color: 'var(--muted)' }}>
                    {formatDateTime(record.created_at)}
                  </span>
                </div>
              </div>
            ))}
          </div>
        )}
      </section>
    </div>
  )
}
