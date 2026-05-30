/**
 * Insights Page (#302)
 *
 * Enhancements:
 * - Parse AI insight response to extract mood drivers, best/worst times, recommendations
 * - Display mood drivers as a horizontal bar chart (sleep, exercise, social, etc.)
 * - Show best time of day as a visual timeline chip
 * - Render recommendations as a numbered card list with icons
 * - "Regenerate insight" button that triggers a fresh AI analysis
 * - Show the date the insight was generated and a freshness indicator
 * - Skeleton loaders during fetch
 * - Mobile-friendly layout
 */
import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'
import type { Insight, LogEntry } from '../../lib/types'
import { formatDateTime, getCountdownLabel } from '../../lib/date'

// ── Constants ─────────────────────────────────────────────────────────────────

const INSIGHTS_FALLBACK_STORAGE_KEY = 'echo-insights-history'

const RECOMMENDATION_ICONS = ['🌱', '💧', '🏃', '😴', '🧘', '📖', '🎵', '🤝', '🌿', '✨']

const TIME_OF_DAY_SLOTS = [
  { label: 'Morning', hours: '6–12', icon: '🌅' },
  { label: 'Afternoon', hours: '12–17', icon: '☀️' },
  { label: 'Evening', hours: '17–21', icon: '🌆' },
  { label: 'Night', hours: '21–6', icon: '🌙' },
]

// ── Types ─────────────────────────────────────────────────────────────────────

type InsightPayload = {
  prediction: string
  suggestions: string[]
  futureLetter: string
  stressLevel: number
  calmingMessage?: string
  musicRecommendations?: string[]
  // #302 structured fields (parsed from prediction if not present)
  moodDrivers?: { label: string; percentage: number }[]
  bestTimeOfDay?: string
  worstTimeOfDay?: string
  recommendations?: string[]
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function normalizeInsightPayload(input: unknown): InsightPayload {
  if (!input || typeof input !== 'object') {
    throw new Error('Invalid insight payload from edge function.')
  }

  const candidate = input as Record<string, unknown>
  const suggestionsValue = candidate.suggestions
  const suggestions = Array.isArray(suggestionsValue)
    ? suggestionsValue.map((item) => String(item)).slice(0, 5)
    : []

  // Parse mood drivers
  let moodDrivers: { label: string; percentage: number }[] | undefined
  if (Array.isArray(candidate.moodDrivers)) {
    moodDrivers = (candidate.moodDrivers as unknown[])
      .filter((d): d is Record<string, unknown> => typeof d === 'object' && d !== null)
      .map((d) => ({ label: String(d.label ?? ''), percentage: Number(d.percentage ?? 0) }))
      .filter((d) => d.label && d.percentage > 0)
  }

  // Parse recommendations
  let recommendations: string[] | undefined
  if (Array.isArray(candidate.recommendations)) {
    recommendations = (candidate.recommendations as unknown[]).map((r) => String(r)).filter(Boolean)
  }

  return {
    prediction: String(candidate.prediction ?? '').trim(),
    suggestions,
    futureLetter: String(candidate.futureLetter ?? '').trim(),
    stressLevel: Number(candidate.stressLevel ?? 0),
    calmingMessage: String(candidate.calmingMessage ?? '').trim() || undefined,
    musicRecommendations: Array.isArray(candidate.musicRecommendations)
      ? (candidate.musicRecommendations as unknown[]).map((m) => String(m))
      : [],
    moodDrivers,
    bestTimeOfDay: candidate.bestTimeOfDay ? String(candidate.bestTimeOfDay) : undefined,
    worstTimeOfDay: candidate.worstTimeOfDay ? String(candidate.worstTimeOfDay) : undefined,
    recommendations,
  }
}

function getLocalInsights(userId: string): Insight[] {
  const raw = localStorage.getItem(INSIGHTS_FALLBACK_STORAGE_KEY)
  if (!raw) return []
  try {
    const all = JSON.parse(raw) as Insight[]
    return all.filter((item) => item.user_id === userId)
  } catch {
    return []
  }
}

function setLocalInsights(items: Insight[]) {
  localStorage.setItem(INSIGHTS_FALLBACK_STORAGE_KEY, JSON.stringify(items))
}

function getFreshnessLabel(createdAt: string): { label: string; color: string } {
  const diffMs = Date.now() - new Date(createdAt).getTime()
  const diffHours = diffMs / (1000 * 60 * 60)
  if (diffHours < 1) return { label: 'Just generated', color: '#22c55e' }
  if (diffHours < 24) return { label: `${Math.floor(diffHours)}h ago`, color: '#22c55e' }
  const diffDays = Math.floor(diffHours / 24)
  if (diffDays < 7) return { label: `${diffDays}d ago`, color: '#f97316' }
  return { label: `${diffDays}d ago — consider regenerating`, color: '#f43f5e' }
}

function getStressLabel(level: number): string {
  if (level <= 1) return 'Very Low'
  if (level <= 2) return 'Low'
  if (level <= 3) return 'Moderate'
  if (level <= 4) return 'High'
  return 'Very High'
}

function parseMoodDriversFromText(text: string): { label: string; percentage: number }[] {
  const matches = [...text.matchAll(/([A-Za-z][A-Za-z\s-]{1,24})\s*[:=-]?\s*(\d{1,3})%/g)]
  return matches
    .map((match) => ({
      label: match[1].trim().replace(/\s+/g, ' '),
      percentage: Math.min(100, Math.max(0, Number(match[2]))),
    }))
    .filter((driver) => driver.label && driver.percentage > 0)
    .slice(0, 6)
}

function inferTimeOfDay(text: string): string | null {
  const normalized = text.toLowerCase()
  const slot = TIME_OF_DAY_SLOTS.find((item) => normalized.includes(item.label.toLowerCase()))
  return slot?.label ?? null
}

// ── Data fetchers ─────────────────────────────────────────────────────────────

async function fetchRecentLogs(userId: string): Promise<LogEntry[]> {
  const { data, error } = await supabase
    .from('log_entries')
    .select('*')
    .eq('user_id', userId)
    .order('date', { ascending: false })
    .limit(30)
  if (error) throw error
  return (data ?? []) as LogEntry[]
}

async function fetchInsightHistory(userId: string): Promise<Insight[]> {
  const { data, error } = await supabase
    .from('ai_insights')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(10)
  if (error) return getLocalInsights(userId)
  const rows = (data ?? []) as Insight[]
  if (!rows.length) return getLocalInsights(userId)
  return rows
}

async function persistInsight(insight: Insight) {
  const { error } = await supabase.from('ai_insights').insert({
    id: insight.id,
    user_id: insight.user_id,
    prediction: insight.prediction,
    suggestions: insight.suggestions,
    future_letter: insight.future_letter,
    stress_level: insight.stress_level,
    calming_message: insight.calming_message,
    music_recommendations: insight.music_recommendations,
    mood_drivers: insight.mood_drivers ?? [],
    best_time_of_day: insight.best_time_of_day,
    worst_time_of_day: insight.worst_time_of_day,
    recommendations: insight.recommendations ?? insight.suggestions,
    created_at: insight.created_at,
  })
  if (error) {
    const existing = getLocalInsights(insight.user_id)
    setLocalInsights([insight, ...existing].slice(0, 10))
  }
}

async function generateInsight(userId: string, recentLogs: LogEntry[]): Promise<Insight> {
  const { data, error } = await supabase.functions.invoke('generate-insight', {
    body: {
      recentLogs: recentLogs.map((entry) => ({
        date: entry.date,
        mood: entry.mood,
        habits: entry.habits,
        notes: entry.notes,
      })),
    },
  })
  if (error) throw error

  const normalized = normalizeInsightPayload(data)
  if (!normalized.prediction || !normalized.futureLetter) {
    throw new Error('AI response missed required insight fields.')
  }

  const createdAt = new Date().toISOString()
  const insight: Insight = {
    id: crypto.randomUUID(),
    user_id: userId,
    prediction: normalized.prediction,
    suggestions: normalized.suggestions,
    future_letter: normalized.futureLetter,
    stress_level: Math.min(5, Math.max(0, normalized.stressLevel)),
    calming_message: normalized.calmingMessage,
    music_recommendations: normalized.musicRecommendations,
    mood_drivers: normalized.moodDrivers ?? parseMoodDriversFromText(normalized.prediction),
    best_time_of_day: normalized.bestTimeOfDay ?? inferTimeOfDay(normalized.prediction),
    worst_time_of_day: normalized.worstTimeOfDay ?? null,
    recommendations: normalized.recommendations ?? normalized.suggestions,
    created_at: createdAt,
  }

  await persistInsight(insight)
  return insight
}

// ── Sub-components ────────────────────────────────────────────────────────────

function SkeletonBlock({ width = '100%', height = 16 }: { width?: string | number; height?: number }) {
  return (
    <div
      aria-hidden="true"
      style={{
        width,
        height,
        borderRadius: 6,
        background: 'var(--surface-soft)',
        animation: 'skeleton-shimmer 1.4s ease-in-out infinite',
      }}
    />
  )
}

function InsightSkeleton() {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
      <SkeletonBlock height={20} width="60%" />
      <SkeletonBlock height={14} />
      <SkeletonBlock height={14} width="85%" />
      <SkeletonBlock height={14} width="70%" />
      <div style={{ display: 'flex', gap: '0.5rem', marginTop: '0.5rem' }}>
        <SkeletonBlock height={32} width={80} />
        <SkeletonBlock height={32} width={80} />
        <SkeletonBlock height={32} width={80} />
      </div>
    </div>
  )
}

function MoodDriversChart({ drivers }: { drivers: { label: string; percentage: number }[] }) {
  const sorted = [...drivers].sort((a, b) => b.percentage - a.percentage)
  const colors = ['#1463ff', '#22c55e', '#f97316', '#8b5cf6', '#f43f5e', '#0a8a5b']

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '0.6rem' }}>
      {sorted.map((driver, i) => (
        <div key={driver.label}>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '0.2rem', fontSize: '0.82rem' }}>
            <span style={{ color: 'var(--text)', fontWeight: 500 }}>{driver.label}</span>
            <span style={{ color: 'var(--muted)' }}>{driver.percentage}%</span>
          </div>
          <div
            style={{
              height: 8,
              borderRadius: 999,
              background: 'var(--surface-soft)',
              overflow: 'hidden',
            }}
            role="progressbar"
            aria-valuenow={driver.percentage}
            aria-valuemin={0}
            aria-valuemax={100}
            aria-label={`${driver.label}: ${driver.percentage}%`}
          >
            <div
              style={{
                height: '100%',
                width: `${driver.percentage}%`,
                borderRadius: 999,
                background: colors[i % colors.length],
                transition: 'width 0.6s ease',
              }}
            />
          </div>
        </div>
      ))}
    </div>
  )
}

function TimeOfDayChip({ timeLabel }: { timeLabel: string }) {
  const normalized = timeLabel.toLowerCase()
  const slot = TIME_OF_DAY_SLOTS.find((s) => normalized.includes(s.label.toLowerCase())) ?? TIME_OF_DAY_SLOTS[0]

  return (
    <div
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: '0.4rem',
        padding: '0.35rem 0.85rem',
        borderRadius: '999px',
        background: 'var(--surface-soft)',
        border: '1px solid var(--line)',
        fontSize: '0.85rem',
        fontWeight: 600,
        color: 'var(--text)',
      }}
    >
      <span>{slot.icon}</span>
      <span>{slot.label}</span>
      <span style={{ color: 'var(--muted)', fontWeight: 400 }}>{slot.hours}</span>
    </div>
  )
}

function RecommendationCards({ recommendations }: { recommendations: string[] }) {
  return (
    <ol style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: '0.6rem' }}>
      {recommendations.map((rec, i) => (
        <li
          key={i}
          style={{
            display: 'flex',
            alignItems: 'flex-start',
            gap: '0.75rem',
            padding: '0.65rem 0.85rem',
            borderRadius: '10px',
            background: 'var(--surface-soft)',
            border: '1px solid var(--line)',
          }}
        >
          <span
            style={{
              fontSize: '1.1rem',
              lineHeight: 1,
              flexShrink: 0,
              marginTop: '0.1rem',
            }}
            aria-hidden="true"
          >
            {RECOMMENDATION_ICONS[i % RECOMMENDATION_ICONS.length]}
          </span>
          <div>
            <span
              style={{
                display: 'inline-block',
                width: 20,
                height: 20,
                borderRadius: '50%',
                background: 'var(--brand)',
                color: '#fff',
                fontSize: '0.7rem',
                fontWeight: 700,
                textAlign: 'center',
                lineHeight: '20px',
                marginRight: '0.4rem',
                flexShrink: 0,
              }}
              aria-hidden="true"
            >
              {i + 1}
            </span>
            <span style={{ fontSize: '0.85rem', color: 'var(--text)' }}>{rec}</span>
          </div>
        </li>
      ))}
    </ol>
  )
}

function FreshnessIndicator({ createdAt }: { createdAt: string }) {
  const { label, color } = getFreshnessLabel(createdAt)
  return (
    <span
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: '0.3rem',
        fontSize: '0.75rem',
        color,
        fontWeight: 500,
      }}
    >
      <span
        style={{
          width: 6,
          height: 6,
          borderRadius: '50%',
          background: color,
          display: 'inline-block',
        }}
        aria-hidden="true"
      />
      {label}
    </span>
  )
}

// ── Page ──────────────────────────────────────────────────────────────────────

export function InsightsPage() {
  const { user } = useAuth()
  const queryClient = useQueryClient()
  const [expandedInsightId, setExpandedInsightId] = useState<string | null>(null)
  const [envelopeOpened, setEnvelopeOpened] = useState(false)

  const logsQuery = useQuery({
    queryKey: ['insight-logs', user?.id],
    queryFn: () => fetchRecentLogs(user!.id),
    enabled: Boolean(user?.id),
  })

  const historyQuery = useQuery({
    queryKey: ['insight-history', user?.id],
    queryFn: () => fetchInsightHistory(user!.id),
    enabled: Boolean(user?.id),
  })

  const generateMutation = useMutation({
    mutationFn: async () => generateInsight(user!.id, logsQuery.data ?? []),
    onSuccess: async (created) => {
      setEnvelopeOpened(false)
      setExpandedInsightId(created.id)
      await queryClient.invalidateQueries({ queryKey: ['insight-history', user?.id] })
    },
  })

  if (!user) return null

  const canGenerate = (logsQuery.data?.length ?? 0) >= 3
  const isPending = generateMutation.isPending
  const currentInsight = generateMutation.data ?? historyQuery.data?.[0] ?? null
  const createdAt = currentInsight?.created_at ? new Date(currentInsight.created_at) : null
  const unlockAt = createdAt ? new Date(createdAt.getTime() + 30 * 24 * 60 * 60 * 1000) : null
  const isFutureLetterLocked = unlockAt ? unlockAt.getTime() > Date.now() : false
  const history = useMemo(() => (historyQuery.data ?? []).slice(0, 5), [historyQuery.data])

  const todayMidnight = new Date()
  todayMidnight.setHours(0, 0, 0, 0)
  const lastGeneratedToday = createdAt
    ? createdAt.getTime() >= todayMidnight.getTime()
    : false
  const isRateLimited = canGenerate && lastGeneratedToday && !generateMutation.data

  const moodDrivers: { label: string; percentage: number }[] = useMemo(() => {
    if (!currentInsight) return []
    if (currentInsight.mood_drivers?.length) return currentInsight.mood_drivers
    return parseMoodDriversFromText(currentInsight.prediction)
  }, [currentInsight])
  const recommendations = currentInsight?.recommendations?.length
    ? currentInsight.recommendations
    : currentInsight?.suggestions ?? []
  const bestTimeOfDay = currentInsight?.best_time_of_day
    ?? (currentInsight ? inferTimeOfDay(currentInsight.prediction) : null)
    ?? 'Morning'

  return (
    <section className="feature-grid insights-grid">
      {/* Generate / Regenerate */}
      <article className="card">
        <h2>
          {currentInsight ? 'Regenerate Insight' : 'Generate Insight'}
        </h2>

        {currentInsight && (
          <div style={{ marginBottom: '0.75rem' }}>
            <p className="muted" style={{ margin: '0 0 0.25rem', fontSize: '0.82rem' }}>
              Last generated: {formatDateTime(currentInsight.created_at)}
            </p>
            <FreshnessIndicator createdAt={currentInsight.created_at} />
          </div>
        )}

        <button
          type="button"
          onClick={() => generateMutation.mutate()}
          disabled={!canGenerate || isPending || isRateLimited}
          style={{ display: 'flex', alignItems: 'center', gap: '0.4rem' }}
        >
          {isPending ? (
            <>
              <span
                style={{
                  width: 14,
                  height: 14,
                  border: '2px solid currentColor',
                  borderTopColor: 'transparent',
                  borderRadius: '50%',
                  display: 'inline-block',
                  animation: 'spin 0.7s linear infinite',
                }}
                aria-hidden="true"
              />
              Analysing your logs…
            </>
          ) : currentInsight ? (
            '🔄 Regenerate insight'
          ) : (
            '✨ Generate insight'
          )}
        </button>

        {!canGenerate && (
          <p className="muted" style={{ marginTop: '0.5rem', fontSize: '0.85rem' }}>
            Log at least 3 moods to unlock your first insight.
          </p>
        )}

        {isRateLimited && (
          <p className="muted" style={{ marginTop: '0.5rem', fontSize: '0.85rem' }}>
            You have already generated an insight today. Come back tomorrow.
          </p>
        )}

        {generateMutation.error && (
          <div style={{ marginTop: '0.75rem' }}>
            <p className="error-text">{(generateMutation.error as Error).message}</p>
            <button type="button" onClick={() => generateMutation.mutate()} style={{ marginTop: '0.4rem' }}>
              Retry
            </button>
          </div>
        )}
      </article>

      {/* Current Insight */}
      <article className="card">
        <h2>Current Insight</h2>

        {isPending ? (
          <InsightSkeleton />
        ) : !currentInsight ? (
          <p className="muted">No insight generated yet.</p>
        ) : (
          <>
            {/* Prediction */}
            <p style={{ marginTop: 0 }}>{currentInsight.prediction}</p>

            {/* Mood Drivers Bar Chart */}
            {moodDrivers.length > 0 && (
              <div style={{ marginTop: '1.25rem' }}>
                <p className="field-label" style={{ marginBottom: '0.6rem', fontWeight: 600 }}>
                  Mood Drivers
                </p>
                <MoodDriversChart drivers={moodDrivers} />
              </div>
            )}

            {/* Best Time of Day */}
            <div style={{ marginTop: '1.25rem' }}>
              <p className="field-label" style={{ marginBottom: '0.5rem', fontWeight: 600 }}>
                Best time of day
              </p>
              <TimeOfDayChip timeLabel={bestTimeOfDay} />
            </div>

            {/* Recommendations */}
            {recommendations.length > 0 && (
              <div style={{ marginTop: '1.25rem' }}>
                <p className="field-label" style={{ marginBottom: '0.6rem', fontWeight: 600 }}>
                  Recommendations
                </p>
                <RecommendationCards recommendations={recommendations} />
              </div>
            )}

            {/* Stress meter */}
            <div
              className="stress-meter"
              style={{ ['--stress' as string]: String(currentInsight.stress_level), marginTop: '1.25rem' }}
            >
              <p style={{ margin: '0 0 0.4rem', fontSize: '0.85rem' }}>
                Stress level: <strong>{currentInsight.stress_level}/5</strong>{' '}
                <span className="muted">({getStressLabel(currentInsight.stress_level)})</span>
              </p>
              <div className="stress-bar">
                <span />
              </div>
            </div>

            {/* Calming message */}
            {currentInsight.calming_message && (
              <blockquote className="insight-quote" style={{ marginTop: '1rem' }}>
                {currentInsight.calming_message}
              </blockquote>
            )}

            {/* Music recommendations */}
            {currentInsight.music_recommendations && currentInsight.music_recommendations.length > 0 && (
              <div className="music-recommendations" style={{ marginTop: '1rem' }}>
                <p className="field-label" style={{ fontWeight: 600 }}>Music for you</p>
                <ul style={{ margin: '0.4rem 0 0', paddingLeft: '1.2rem' }}>
                  {currentInsight.music_recommendations.map((m, i) => (
                    <li key={i} style={{ fontSize: '0.85rem', marginBottom: '0.2rem' }}>{m}</li>
                  ))}
                </ul>
              </div>
            )}

            {/* Future Letter */}
            <div className={envelopeOpened ? 'envelope open' : 'envelope'} style={{ marginTop: '1.25rem' }}>
              <p className="field-label" style={{ fontWeight: 600 }}>Future Letter</p>
              {isFutureLetterLocked ? (
                <p className="muted">🔒 Unlocks in {getCountdownLabel(unlockAt!.toISOString())}</p>
              ) : envelopeOpened ? (
                <p style={{ fontSize: '0.9rem', lineHeight: 1.6 }}>{currentInsight.future_letter}</p>
              ) : (
                <button type="button" onClick={() => setEnvelopeOpened(true)}>
                  Open envelope
                </button>
              )}
            </div>
          </>
        )}
      </article>

      {/* Insight History */}
      <article className="card full-width">
        <h2>Insight History</h2>

        {historyQuery.isLoading ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.6rem' }}>
            {[1, 2, 3].map((n) => <SkeletonBlock key={n} height={56} />)}
          </div>
        ) : (
          <div className="list-stack">
            {history.map((insight) => {
              const expanded = expandedInsightId === insight.id
              return (
                <button
                  type="button"
                  key={insight.id}
                  className="list-card align-left"
                  onClick={() => setExpandedInsightId((prev) => (prev === insight.id ? null : insight.id))}
                  aria-expanded={expanded}
                >
                  <div className="list-card-row">
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '0.15rem' }}>
                      <strong>{formatDateTime(insight.created_at)}</strong>
                      <FreshnessIndicator createdAt={insight.created_at} />
                    </div>
                    <span>{expanded ? 'Hide ▲' : 'Expand ▼'}</span>
                  </div>
                  <p className="muted note-preview">{insight.prediction.slice(0, 160)}…</p>
                  {expanded && (
                    <div className="expanded-area" style={{ marginTop: '0.75rem' }}>
                      <p style={{ fontSize: '0.9rem' }}>{insight.prediction}</p>
                      {insight.calming_message && (
                        <blockquote className="insight-quote">{insight.calming_message}</blockquote>
                      )}
                      {(insight.recommendations?.length ?? insight.suggestions.length) > 0 && (
                        <div style={{ marginTop: '0.75rem' }}>
                          <p className="field-label" style={{ fontWeight: 600, marginBottom: '0.4rem' }}>Recommendations</p>
                          <RecommendationCards recommendations={insight.recommendations?.length ? insight.recommendations : insight.suggestions} />
                        </div>
                      )}
                      <p className="muted" style={{ marginTop: '0.75rem', fontSize: '0.82rem' }}>
                        Future letter preview: {insight.future_letter.slice(0, 120)}…
                      </p>
                    </div>
                  )}
                </button>
              )
            })}

            {!history.length && <p className="muted">No historical insights yet.</p>}
          </div>
        )}
      </article>

      {/* Keyframe animations */}
      <style>{`
        @keyframes skeleton-shimmer {
          0%, 100% { opacity: 1; }
          50%       { opacity: 0.4; }
        }
        @keyframes spin {
          to { transform: rotate(360deg); }
        }
      `}</style>
    </section>
  )
}
