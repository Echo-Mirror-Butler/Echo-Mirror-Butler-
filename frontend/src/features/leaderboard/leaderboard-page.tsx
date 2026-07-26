import { useEffect, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'

type LeaderboardEntry = {
  id: string
  display_name: string | null
  avatar_url: string | null
  leaderboard_anonymous: boolean
  echo_earned_this_week: number
  rank: number
}

async function fetchLeaderboard(): Promise<LeaderboardEntry[]> {
  const { data, error } = await supabase
    .from('leaderboard_weekly')
    .select()
    .order('rank', { ascending: true })
    .limit(20)
  if (error) throw error
  return (data ?? []) as LeaderboardEntry[]
}

function medal(rank: number): string {
  if (rank === 1) return '\u{1F947}'
  if (rank === 2) return '\u{1F948}'
  if (rank === 3) return '\u{1F949}'
  return `#${rank}`
}

export function LeaderboardPage() {
  const { user } = useAuth()
  const [refreshKey, setRefreshKey] = useState(0)

  const query = useQuery({
    queryKey: ['leaderboard', refreshKey],
    queryFn: fetchLeaderboard,
    refetchInterval: 300_000,
  })

  const entries = query.data ?? []
  const currentUserEntry = entries.find((e) => e.id === user?.id)
  const isInTop20 = Boolean(currentUserEntry)

  return (
    <div className="page-wrap animate-stagger" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h1 style={{ margin: 0 }}>Weekly Leaderboard</h1>
        <button type="button" className="chip" onClick={() => setRefreshKey((k) => k + 1)}>
          Refresh
        </button>
      </div>

      {query.isLoading && <div className="card"><p className="muted">Loading…</p></div>}
      {query.isError && (
        <div className="card">
          <p className="error-text">Failed to load leaderboard.</p>
          <button type="button" onClick={() => setRefreshKey((k) => k + 1)}>Retry</button>
        </div>
      )}

      {!query.isLoading && entries.length === 0 && (
        <div className="card" style={{ textAlign: 'center', padding: '3rem 1rem' }}>
          <div style={{ fontSize: '3rem', marginBottom: '0.5rem' }}>🏆</div>
          <p>No entries this week yet.</p>
        </div>
      )}

      {entries.map((entry) => {
        const isMe = entry.id === user?.id
        return (
          <div
            key={entry.id}
            className="card"
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '1rem',
              padding: '0.75rem 1rem',
              background: isMe ? 'color-mix(in srgb, var(--brand) 8%, var(--surface))' : undefined,
              border: isMe ? '1px solid var(--brand)' : undefined,
            }}
          >
            <span style={{ fontSize: '1.2rem', minWidth: '2rem', textAlign: 'center' }}>
              {medal(entry.rank)}
            </span>
            <div style={{ flex: 1 }}>
              <strong>{entry.display_name ?? 'User'}</strong>
              {isMe && <span className="chip active" style={{ marginLeft: '0.5rem', fontSize: '0.7rem' }}>You</span>}
            </div>
            <span style={{ fontWeight: 600, color: 'var(--brand)' }}>
              {entry.echo_earned_this_week} ECHO
            </span>
          </div>
        )
      })}

      {!isInTop20 && user && (
        <>
          <hr style={{ border: 'none', borderTop: '1px solid var(--line)' }} />
          <p className="muted" style={{ textAlign: 'center' }}>Your rank is outside the top 20.</p>
        </>
      )}
    </div>
  )
}
