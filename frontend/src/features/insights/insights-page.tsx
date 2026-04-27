import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'
import type { Insight, LogEntry } from '../../lib/types'
import { formatDateTime, getCountdownLabel } from '../../lib/date'

const INSIGHTS_FALLBACK_STORAGE_KEY = 'echo-insights-history'

type InsightPayload = {
  prediction: string
  suggestions: string[]
  futureLetter: string
  stressLevel: number
}

function normalizeInsightPayload(input: unknown): InsightPayload {
  if (!input || typeof input !== 'object') {
    throw new Error('Invalid insight payload from edge function.')
  }

  const candidate = input as Record<string, unknown>
  const suggestionsValue = candidate.suggestions
  const suggestions = Array.isArray(suggestionsValue)
    ? suggestionsValue.map((item) => String(item)).slice(0, 5)
    : []

  return {
    prediction: String(candidate.prediction ?? '').trim(),
    suggestions,
    futureLetter: String(candidate.futureLetter ?? '').trim(),
    stressLevel: Number(candidate.stressLevel ?? 0),
  }
}

function getLocalInsights(userId: string): Insight[] {
  const raw = localStorage.getItem(INSIGHTS_FALLBACK_STORAGE_KEY)
  if (!raw) {
    return []
  }

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

async function fetchRecentLogs(userId: string): Promise<LogEntry[]> {
  const { data, error } = await supabase
    .from('log_entries')
    .select('*')
    .eq('user_id', userId)
    .order('date', { ascending: false })
    .limit(30)

  if (error) {
    throw error
  }

  return (data ?? []) as LogEntry[]
}

async function fetchInsightHistory(userId: string): Promise<Insight[]> {
  const { data, error } = await supabase
    .from('ai_insights')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(10)

  if (error) {
    return getLocalInsights(userId)
  }

  const rows = (data ?? []) as Insight[]
  if (!rows.length) {
    return getLocalInsights(userId)
  }

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

  if (error) {
    throw error
  }

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
    created_at: createdAt,
  }

  await persistInsight(insight)
  return insight
}

function getStressLabel(level: number): string {
  if (level <= 1) {
    return 'Very Low'
  }
  if (level <= 2) {
    return 'Low'
  }
  if (level <= 3) {
    return 'Moderate'
  }
  if (level <= 4) {
    return 'High'
  }
  return 'Very High'
}

export function InsightsPage() {
  const { user } = useAuth()
  const queryClient = useQueryClient()
  const [expandedInsightId, setExpandedInsightId] = useState<string | null>(null)
  const [doneSuggestions, setDoneSuggestions] = useState<Record<string, boolean>>({})
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
    mutationFn: async () => {
      return generateInsight(user!.id, logsQuery.data ?? [])
    },
    onSuccess: async (created) => {
      setEnvelopeOpened(false)
      setExpandedInsightId(created.id)
      await queryClient.invalidateQueries({ queryKey: ['insight-history', user?.id] })
    },
  })

  if (!user) {
    return null
  }

  const canGenerate = (logsQuery.data?.length ?? 0) >= 3
  const currentInsight = generateMutation.data ?? historyQuery.data?.[0] ?? null
  const createdAt = currentInsight?.created_at ? new Date(currentInsight.created_at) : null
  const unlockAt = createdAt ? new Date(createdAt.getTime() + 30 * 24 * 60 * 60 * 1000) : null
  const isFutureLetterLocked = unlockAt ? unlockAt.getTime() > Date.now() : false

  const history = useMemo(() => (historyQuery.data ?? []).slice(0, 5), [historyQuery.data])

  return (
    <section className="feature-grid insights-grid">
      <article className="card">
        <h2>Generate Insight</h2>
        <button
          type="button"
          onClick={() => generateMutation.mutate()}
          disabled={!canGenerate || generateMutation.isPending}
        >
          {generateMutation.isPending ? 'Analysing your logs…' : 'Generate New Insight'}
        </button>

        {!canGenerate ? <p className="muted">At least 3 logs are required to generate insights.</p> : null}
        {generateMutation.error ? (
          <div>
            <p className="error-text">{(generateMutation.error as Error).message}</p>
            <button type="button" onClick={() => generateMutation.mutate()}>
              Retry
            </button>
          </div>
        ) : null}
      </article>

      <article className="card">
        <h2>Current Insight</h2>
        {!currentInsight ? (
          <p className="muted">No insight generated yet.</p>
        ) : (
          <>
            <p>{currentInsight.prediction}</p>

            <div>
              <p className="field-label">Suggestions</p>
              <div className="chip-row compact">
                {currentInsight.suggestions.map((suggestion, index) => {
                  const key = `${currentInsight.id}-${index}`
                  const done = Boolean(doneSuggestions[key])
                  return (
                    <button
                      key={key}
                      type="button"
                      className={done ? 'chip active' : 'chip'}
                      onClick={() =>
                        setDoneSuggestions((prev) => ({
                          ...prev,
                          [key]: !prev[key],
                        }))
                      }
                    >
                      {done ? '✓ ' : ''}
                      {suggestion}
                    </button>
                  )
                })}
              </div>
            </div>

            <div className="stress-meter" style={{ ['--stress' as string]: String(currentInsight.stress_level) }}>
              <p>
                Stress level: {currentInsight.stress_level}/5 ({getStressLabel(currentInsight.stress_level)})
              </p>
              <div className="stress-bar">
                <span />
              </div>
            </div>

            <div className={envelopeOpened ? 'envelope open' : 'envelope'}>
              <p className="field-label">Future Letter</p>
              {isFutureLetterLocked ? (
                <p className="muted">🔒 Unlocks in {getCountdownLabel(unlockAt!.toISOString())}</p>
              ) : envelopeOpened ? (
                <p>{currentInsight.future_letter}</p>
              ) : (
                <button type="button" onClick={() => setEnvelopeOpened(true)}>
                  Open envelope
                </button>
              )}
            </div>
          </>
        )}
      </article>

      <article className="card full-width">
        <h2>Insight History</h2>

        <div className="list-stack">
          {history.map((insight) => {
            const expanded = expandedInsightId === insight.id
            return (
              <button
                type="button"
                key={insight.id}
                className="list-card align-left"
                onClick={() => setExpandedInsightId((prev) => (prev === insight.id ? null : insight.id))}
              >
                <div className="list-card-row">
                  <strong>{formatDateTime(insight.created_at)}</strong>
                  <span>{expanded ? 'Hide' : 'Expand'}</span>
                </div>
                <p className="muted note-preview">{insight.prediction.slice(0, 160)}…</p>
                {expanded ? (
                  <div className="expanded-area">
                    <p>{insight.prediction}</p>
                    <p className="muted">Future letter preview: {insight.future_letter.slice(0, 120)}…</p>
                  </div>
                ) : null}
              </button>
            )
          })}

          {!history.length ? <p className="muted">No historical insights yet.</p> : null}
        </div>
      </article>
    </section>
  )
}
