/**
 * RecapPage — Issue #617 (personal "year in review" / periodic recap)
 *
 * PLATFORM SCOPE: web frontend only for this change. The Flutter client is
 * intentionally NOT modified here — no Dart toolchain was available to verify
 * a mobile port, and issue #617 explicitly allows scoping to one platform
 * first. A Flutter equivalent is deferred to a follow-up.
 *
 * Aggregation lives in ./recap.ts (pure, unit-tested). The shareable image
 * reuses the Canvas export pattern via ./recap-canvas.ts.
 */
import { useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'
import { useToast } from '../../lib/use-toast'
import {
  computeRecap,
  hasSufficientHistory,
  MIN_LOGS_FOR_RECAP,
  PERIOD_LABELS,
  type RecapEchoTxn,
  type RecapInput,
  type RecapPeriod,
} from './recap'
import { shareRecapCard } from './recap-canvas'

type LogRow = { date: string; mood: number | null; habits: string[] | null }
type RewardRow = { amount: number | null; created_at: string }
type GiftRow = { echo_amount: number | null; created_at: string }
type AchievementRow = { achievement_id: string; unlocked_at: string }

async function fetchRecapInput(userId: string): Promise<RecapInput> {
  const [logsRes, rewardsRes, giftsRes, achievementsRes] = await Promise.all([
    supabase.from('log_entries').select('date, mood, habits').eq('user_id', userId),
    supabase.from('echo_rewards').select('amount, created_at').eq('user_id', userId),
    supabase
      .from('gift_transactions')
      .select('echo_amount, created_at')
      .eq('sender_user_id', userId),
    supabase
      .from('user_achievements')
      .select('achievement_id, unlocked_at')
      .eq('user_id', userId),
  ])

  const logs = ((logsRes.data as LogRow[] | null) ?? []).map((r) => ({
    date: r.date,
    mood: r.mood,
    habits: Array.isArray(r.habits) ? r.habits : [],
  }))

  const echoTransactions: RecapEchoTxn[] = [
    ...((rewardsRes.data as RewardRow[] | null) ?? []).map((r) => ({
      amount: r.amount ?? 0,
      direction: 'earned' as const,
      date: r.created_at,
    })),
    ...((giftsRes.data as GiftRow[] | null) ?? []).map((g) => ({
      amount: g.echo_amount ?? 0,
      direction: 'spent' as const,
      date: g.created_at,
    })),
  ]

  const achievements = ((achievementsRes.data as AchievementRow[] | null) ?? []).map((a) => ({
    achievement_id: a.achievement_id,
    unlocked_at: a.unlocked_at,
  }))

  return { logs, echoTransactions, achievements }
}

function StatTile({ label, value }: { label: string; value: string }) {
  return (
    <div
      style={{
        background: 'var(--surface)',
        border: '1px solid var(--line)',
        borderRadius: 16,
        padding: '1.25rem',
        textAlign: 'center',
      }}
    >
      <div style={{ fontSize: '1.9rem', fontWeight: 700, color: 'var(--brand)' }}>{value}</div>
      <div className="muted" style={{ fontSize: '0.8rem', marginTop: 4 }}>
        {label}
      </div>
    </div>
  )
}

export function RecapPage() {
  const { user } = useAuth()
  const { showToast } = useToast()
  const [period, setPeriod] = useState<RecapPeriod>('all_time')
  const [sharing, setSharing] = useState(false)

  const userId = user?.id
  const signupDate = (user?.created_at as string | undefined) ?? null

  const { data, isLoading, error } = useQuery({
    queryKey: ['recap-input', userId],
    queryFn: () => fetchRecapInput(userId as string),
    enabled: !!userId,
  })

  const totalLogCount = data?.logs.length ?? 0
  const eligible = useMemo(
    () => hasSufficientHistory(totalLogCount, signupDate),
    [totalLogCount, signupDate],
  )

  const recap = useMemo(
    () => (data ? computeRecap(data, period) : null),
    [data, period],
  )

  const handleShare = async () => {
    if (!recap || sharing) return
    setSharing(true)
    try {
      const result = await shareRecapCard(recap)
      if (result === 'downloaded') showToast('Recap image downloaded', 'success')
      else if (result === 'shared') showToast('Recap shared', 'success')
    } catch {
      showToast('Could not create recap image', 'error')
    } finally {
      setSharing(false)
    }
  }

  if (!user) return null

  return (
    <section className="feature-grid" style={{ display: 'block', maxWidth: 720, margin: '0 auto' }}>
      <div className="card">
        <div className="card-header" style={{ display: 'flex', justifyContent: 'space-between' }}>
          <h3>Your Recap</h3>
        </div>
        <div className="card-content form-stack">
          {isLoading && <p className="muted">Building your recap…</p>}

          {error && (
            <p role="alert" className="error-text">
              Could not load your recap. Please try again.
            </p>
          )}

          {!isLoading && !error && !eligible && (
            <div
              style={{
                padding: '1.5rem',
                textAlign: 'center',
                background: 'var(--surface)',
                borderRadius: 12,
              }}
            >
              <div style={{ fontSize: '2rem' }}>📊</div>
              <p style={{ fontWeight: 600, margin: '0.5rem 0' }}>Your recap isn’t ready yet</p>
              <p className="muted" style={{ fontSize: '0.88rem', margin: 0 }}>
                {`Keep logging! A recap unlocks after ${MIN_LOGS_FOR_RECAP} logs and 30 days of history. `}
                {`You have ${totalLogCount} log${totalLogCount === 1 ? '' : 's'} so far.`}
              </p>
            </div>
          )}

          {!isLoading && !error && eligible && recap && (
            <>
              {/* Period selector */}
              <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
                {(Object.keys(PERIOD_LABELS) as RecapPeriod[]).map((p) => (
                  <button
                    key={p}
                    type="button"
                    onClick={() => setPeriod(p)}
                    aria-pressed={period === p}
                    style={{
                      padding: '0.4rem 0.9rem',
                      borderRadius: 999,
                      border: '1px solid var(--line)',
                      background: period === p ? 'var(--brand)' : 'var(--surface)',
                      color: period === p ? '#fff' : 'var(--text)',
                      fontSize: '0.85rem',
                      cursor: 'pointer',
                    }}
                  >
                    {PERIOD_LABELS[p]}
                  </button>
                ))}
              </div>

              {/* Stat grid */}
              <div
                style={{
                  display: 'grid',
                  gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))',
                  gap: '0.75rem',
                }}
              >
                <StatTile label="Total logs" value={String(recap.totalLogs)} />
                <StatTile
                  label="Average mood"
                  value={recap.avgMood != null ? String(recap.avgMood) : '—'}
                />
                <StatTile
                  label="Mood trend"
                  value={
                    recap.moodTrend == null
                      ? '—'
                      : `${recap.moodTrend > 0 ? '▲' : recap.moodTrend < 0 ? '▼' : '■'} ${Math.abs(recap.moodTrend)}`
                  }
                />
                <StatTile label="Longest streak" value={`${recap.longestStreak}🔥`} />
                <StatTile label="ECHO earned" value={`${recap.echoEarned}`} />
                <StatTile label="ECHO spent" value={`${recap.echoSpent}`} />
                <StatTile label="Achievements" value={`${recap.achievementsUnlocked}`} />
              </div>

              {/* Top habits */}
              {recap.topHabits.length > 0 && (
                <div>
                  <p style={{ fontWeight: 600, margin: '0 0 0.5rem' }}>Top habits</p>
                  <div style={{ display: 'flex', gap: '0.4rem', flexWrap: 'wrap' }}>
                    {recap.topHabits.map((h, i) => (
                      <span
                        key={h.habit}
                        style={{
                          background: 'var(--surface)',
                          border: '1px solid var(--line)',
                          borderRadius: 999,
                          padding: '0.3rem 0.75rem',
                          fontSize: '0.82rem',
                        }}
                      >
                        {['🥇', '🥈', '🥉'][i] ?? '•'} {h.habit} ({h.count})
                      </span>
                    ))}
                  </div>
                </div>
              )}

              {/* Highlights */}
              <div className="muted" style={{ fontSize: '0.85rem' }}>
                {recap.highlights.bestDay && (
                  <p style={{ margin: '0.2rem 0' }}>
                    🌟 Best day: {recap.highlights.bestDay.date} (mood {recap.highlights.bestDay.mood})
                  </p>
                )}
                {recap.highlights.mostActiveMonth && (
                  <p style={{ margin: '0.2rem 0' }}>
                    📅 Most active month: {recap.highlights.mostActiveMonth.month} (
                    {recap.highlights.mostActiveMonth.logs} logs)
                  </p>
                )}
              </div>

              <button
                type="button"
                onClick={() => void handleShare()}
                disabled={sharing}
                style={{
                  padding: '0.7rem 1.2rem',
                  borderRadius: 12,
                  border: 'none',
                  background: 'var(--brand)',
                  color: '#fff',
                  fontWeight: 600,
                  fontSize: '0.95rem',
                  cursor: sharing ? 'not-allowed' : 'pointer',
                  width: 'fit-content',
                }}
              >
                {sharing ? 'Preparing…' : '📤 Share recap image'}
              </button>
            </>
          )}
        </div>
      </div>
    </section>
  )
}
