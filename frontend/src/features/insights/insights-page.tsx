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
import type { Insight, LogEntry, InsightAction } from '../../lib/types'
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
  moodScore?: number
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
    moodScore: candidate.moodScore ? Number(candidate.moodScore) : undefined
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

async function fetchInsightHistory(userId: string, limit: number = 10): Promise<Insight[]> {
  const { data, error } = await supabase
    .from('ai_insights')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(limit + 1)
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
    mood_score: insight.mood_score,
  })
  if (error) {
    const existing = getLocalInsights(insight.user_id)
    setLocalInsights([insight, ...existing].slice(0, 10))
  }
}

async function generateInsight(userId: string, recentLogs: LogEntry[], previousFollowThroughRate?: { acted: number; total: number }): Promise<Insight> {
  const { data, error } = await supabase.functions.invoke('generate-insight', {
    body: {
      recentLogs: recentLogs.map((entry) => ({
        date: entry.date,
        mood: entry.mood,
        habits: entry.habits,
        notes: entry.notes,
      })),
      previousFollowThroughRate,
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
    mood_score: normalized.moodScore ?? null,
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

function MoodDriversChart({ drivers, prediction }: { drivers: { label: string; percentage: number }[]; prediction?: string }) {
  if (drivers.length === 0) {
    return (
      <div style={{ padding: '0.75rem', borderRadius: '8px', background: 'var(--surface-soft)', border: '1px dashed var(--line)', fontSize: '0.85rem', color: 'var(--muted)', fontStyle: 'italic' }}>
        No chart metrics parsed. Fallback raw overview:
        <p style={{ marginTop: '0.4rem', fontStyle: 'normal', color: 'var(--text)' }}>
          {prediction ? (prediction.length > 200 ? prediction.slice(0, 200) + '...' : prediction) : 'No description available.'}
        </p>
      </div>
    )
  }

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

function RecommendationCards({
  insightId,
  recommendations,
  actions,
  onToggle
}: {
  insightId: string
  recommendations: string[]
  actions: InsightAction[]
  onToggle: (index: number, followed: boolean) => void
}) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '0.6rem' }}>
      {recommendations.length > 0 && (
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: '0.85rem', color: 'var(--muted)', fontWeight: 500 }}>
          <span>Completion Rate</span>
          <span>
            You acted on {actions.filter(a => a.followed).length}/{recommendations.length} recommendations
          </span>
        </div>
      )}
      <ol style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: '0.6rem' }}>
        {recommendations.map((rec, i) => {
          const action = actions.find(a => a.recommendation_index === i)
          const isFollowed = action?.followed ?? false

          return (
            <li
              key={i}
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                gap: '0.75rem',
                padding: '0.65rem 0.85rem',
                borderRadius: '10px',
                background: 'var(--surface-soft)',
                border: isFollowed ? '1px solid var(--brand)' : '1px solid var(--line)',
                transition: 'border-color 0.2s ease',
              }}
            >
              <div style={{ display: 'flex', alignItems: 'flex-start', gap: '0.75rem' }}>
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
                      background: isFollowed ? 'var(--brand)' : 'var(--muted)',
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
                  <span style={{ fontSize: '0.85rem', color: isFollowed ? 'var(--text)' : 'var(--text-muted)' }}>{rec}</span>
                </div>
              </div>
              <label style={{ display: 'flex', alignItems: 'center', cursor: 'pointer' }}>
                <input
                  type="checkbox"
                  checked={isFollowed}
                  onChange={(e) => onToggle(i, e.target.checked)}
                  style={{ width: '1.1rem', height: '1.1rem', cursor: 'pointer' }}
                />
              </label>
            </li>
          )
        })}
      </ol>
    </div>
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

function PersonalNoteArea({
  insight,
  onSave
}: {
  insight: Insight
  onSave: (id: string, text: string) => Promise<void>
}) {
  const [editing, setEditing] = useState(false)
  const [tempNote, setTempNote] = useState(insight.personal_note ?? '')

  return (
    <div style={{ marginTop: '0.5rem', padding: '0.5rem 0.75rem', borderRadius: '8px', background: 'var(--surface-soft)', border: '1px solid var(--line)' }}>
      {editing ? (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '0.4rem' }}>
          <textarea
            value={tempNote}
            onChange={(e) => setTempNote(e.target.value)}
            placeholder="Add a personal note (e.g. 'I felt this was accurate')"
            style={{ width: '100%', padding: '0.4rem', fontSize: '0.85rem', background: 'var(--surface)', border: '1px solid var(--line)', borderRadius: '4px', color: 'var(--text)' }}
            rows={2}
          />
          <div style={{ display: 'flex', gap: '0.4rem', justifyContent: 'flex-end' }}>
            <button
              type="button"
              onClick={() => {
                setEditing(false)
                setTempNote(insight.personal_note ?? '')
              }}
              style={{ fontSize: '0.75rem', padding: '0.2rem 0.5rem' }}
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={async () => {
                await onSave(insight.id, tempNote)
                setEditing(false)
              }}
              style={{ fontSize: '0.75rem', padding: '0.2rem 0.5rem' }}
            >
              Save Note
            </button>
          </div>
        </div>
      ) : (
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '0.5rem' }}>
          <span style={{ fontSize: '0.82rem', color: insight.personal_note ? 'var(--text)' : 'var(--muted)', fontStyle: insight.personal_note ? 'normal' : 'italic' }}>
            📝 Note: {insight.personal_note || 'No note added yet.'}
          </span>
          <button
            type="button"
            onClick={() => setEditing(true)}
            style={{ fontSize: '0.75rem', padding: '0.2rem 0.5rem', flexShrink: 0 }}
          >
            {insight.personal_note ? 'Edit' : 'Add Note'}
          </button>
        </div>
      )}
    </div>
  )
}

function InsightComparisonModal({
  latest,
  previous,
  actions,
  onClose
}: {
  latest: Insight
  previous: Insight
  actions: InsightAction[]
  onClose: () => void
}) {
  const latestRecs = latest.recommendations?.length ? latest.recommendations : latest.suggestions ?? []
  const prevRecs = previous.recommendations?.length ? previous.recommendations : previous.suggestions ?? []

  // Calculate gap in days
  const gapMs = Math.abs(new Date(latest.created_at).getTime() - new Date(previous.created_at).getTime())
  const gapDays = Math.round(gapMs / (1000 * 60 * 60 * 24))
  const gapLabel = gapDays === 0 ? 'Same day' : gapDays === 1 ? '1 day later' : `${gapDays} days later`

  // Helper for recommendation comparison
  const normalize = (s: string) => s.toLowerCase().replace(/[^a-z0-9]/g, '')
  const isRecurring = (rec: string) => {
    const norm = normalize(rec)
    return prevRecs.some(pr => {
      const normPr = normalize(pr)
      return norm.includes(normPr) || normPr.includes(norm) || norm === normPr
    })
  }

  // Compile all mood driver labels to compare side-by-side
  const latestDrivers = latest.mood_drivers ?? []
  const prevDrivers = previous.mood_drivers ?? []
  
  const allDriverLabels = Array.from(new Set([
    ...latestDrivers.map(d => d.label),
    ...prevDrivers.map(d => d.label)
  ]))

  const driversComparison = allDriverLabels.map(label => {
    const prevVal = prevDrivers.find(d => d.label === label)?.percentage ?? 0
    const latestVal = latestDrivers.find(d => d.label === label)?.percentage ?? 0
    let trend = '→'
    let trendColor = 'var(--muted)'
    if (latestVal > prevVal) {
      trend = '↑'
      trendColor = '#22c55e'
    } else if (latestVal < prevVal) {
      trend = '↓'
      trendColor = '#f43f5e'
    }
    return { label, prevVal, latestVal, trend, trendColor }
  })

  return (
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      backgroundColor: 'rgba(0,0,0,0.6)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      zIndex: 1000,
      padding: '1rem',
      backdropFilter: 'blur(4px)'
    }}>
      <div style={{
        backgroundColor: 'var(--surface)',
        borderRadius: '16px',
        border: '1px solid var(--line)',
        width: '100%',
        maxWidth: '800px',
        maxHeight: '90vh',
        display: 'flex',
        flexDirection: 'column',
        boxShadow: '0 8px 32px rgba(0,0,0,0.4)',
        overflow: 'hidden'
      }}>
        {/* Modal Header */}
        <div style={{
          padding: '1.25rem 1.5rem',
          borderBottom: '1px solid var(--line)',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          background: 'var(--surface-soft)'
        }}>
          <div>
            <h3 style={{ margin: 0, fontSize: '1.25rem', color: 'var(--text)' }}>Insight Comparison</h3>
            <span style={{ fontSize: '0.8rem', color: 'var(--brand)', fontWeight: 600 }}>
              Timeline Gap: {gapLabel}
            </span>
          </div>
          <button type="button" onClick={onClose} style={{ padding: '0.4rem 0.8rem', fontSize: '0.9rem' }}>
            Close
          </button>
        </div>

        {/* Modal Body */}
        <div style={{ padding: '1.5rem', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
          {/* Mood Drivers Comparison */}
          <div>
            <h4 style={{ margin: '0 0 0.75rem', fontSize: '1rem', borderBottom: '1px solid var(--line)', paddingBottom: '0.25rem' }}>
              📊 Mood Drivers Comparison
            </h4>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
              {driversComparison.map(d => (
                <div key={d.label} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0.4rem 0.75rem', borderRadius: '8px', background: 'var(--surface-soft)' }}>
                  <span style={{ fontWeight: 500, flex: 2 }}>{d.label}</span>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', flex: 1, justifyContent: 'flex-end' }}>
                    <span style={{ fontSize: '0.85rem', color: 'var(--muted)' }}>Prev: {d.prevVal}%</span>
                    <span style={{ fontWeight: 'bold', color: d.trendColor, fontSize: '1.1rem' }}>{d.trend}</span>
                    <span style={{ fontSize: '0.85rem', fontWeight: 600 }}>Curr: {d.latestVal}%</span>
                  </div>
                </div>
              ))}
              {driversComparison.length === 0 && <p className="muted">No mood drivers to compare.</p>}
            </div>
          </div>

          {/* Double Column Recommendations Comparison */}
          <div>
            <h4 style={{ margin: '0 0 0.75rem', fontSize: '1rem', borderBottom: '1px solid var(--line)', paddingBottom: '0.25rem' }}>
              🌱 Recommendations Comparison
            </h4>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
              {/* Previous Column */}
              <div>
                <p style={{ fontWeight: 600, fontSize: '0.85rem', marginBottom: '0.5rem', color: 'var(--muted)' }}>
                  Previous ({formatDateTime(previous.created_at)})
                </p>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                  {prevRecs.map((rec, i) => (
                    <div key={i} style={{ padding: '0.5rem 0.75rem', borderRadius: '8px', background: 'var(--surface-soft)', border: '1px solid var(--line)', fontSize: '0.85rem' }}>
                      {rec}
                    </div>
                  ))}
                  {prevRecs.length === 0 && <p className="muted">No recommendations.</p>}
                </div>
              </div>

              {/* Current Column */}
              <div>
                <p style={{ fontWeight: 600, fontSize: '0.85rem', marginBottom: '0.5rem', color: 'var(--muted)' }}>
                  Latest ({formatDateTime(latest.created_at)})
                </p>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                  {latestRecs.map((rec, i) => {
                    const recurring = isRecurring(rec)
                    return (
                      <div
                        key={i}
                        style={{
                          padding: '0.5rem 0.75rem',
                          borderRadius: '8px',
                          background: recurring ? 'rgba(20, 99, 255, 0.08)' : 'var(--surface-soft)',
                          border: recurring ? '1px solid var(--brand)' : '1px solid var(--line)',
                          fontSize: '0.85rem',
                          position: 'relative'
                        }}
                      >
                        {recurring && (
                          <span style={{
                            position: 'absolute',
                            top: '-8px',
                            right: '8px',
                            background: 'var(--brand)',
                            color: '#fff',
                            fontSize: '0.65rem',
                            padding: '0px 6px',
                            borderRadius: '4px',
                            fontWeight: 700
                          }}>
                            🔄 RECURRING
                          </span>
                        )}
                        {rec}
                      </div>
                    )
                  })}
                  {latestRecs.length === 0 && <p className="muted">No recommendations.</p>}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

// ── Page ──────────────────────────────────────────────────────────────────────

export function InsightsPage() {
  const { user } = useAuth()
  const queryClient = useQueryClient()
  const [expandedInsightId, setExpandedInsightId] = useState<string | null>(null)
  const [envelopeOpened, setEnvelopeOpened] = useState(false)
  const [historyLimit, setHistoryLimit] = useState(10)
  const [historyView, setHistoryView] = useState<'cards' | 'timeline'>('cards')
  const [compareOpen, setCompareOpen] = useState(false)

  const logsQuery = useQuery({
    queryKey: ['insight-logs', user?.id],
    queryFn: () => fetchRecentLogs(user!.id),
    enabled: Boolean(user?.id),
  })

  const historyQuery = useQuery({
    queryKey: ['insight-history', user?.id, historyLimit],
    queryFn: () => fetchInsightHistory(user!.id, historyLimit),
    enabled: Boolean(user?.id),
  })

  const actionsQuery = useQuery({
    queryKey: ['insight-actions', user?.id],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('insight_actions')
        .select('*')
      if (error) throw error
      return (data ?? []) as InsightAction[]
    },
    enabled: Boolean(user?.id),
  })

  const toggleActionMutation = useMutation({
    mutationFn: async ({ insightId, index, followed }: { insightId: string; index: number; followed: boolean }) => {
      const { error } = await supabase
        .from('insight_actions')
        .upsert({
          insight_id: insightId,
          recommendation_index: index,
          followed,
        }, {
          onConflict: 'insight_id,recommendation_index'
        })
      if (error) throw error
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['insight-actions', user?.id] })
    }
  })

  const saveNoteMutation = useMutation({
    mutationFn: async ({ insightId, note }: { insightId: string; note: string }) => {
      const { error } = await supabase
        .from('ai_insights')
        .update({ personal_note: note })
        .eq('id', insightId)
      if (error) throw error
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['insight-history', user?.id] })
    }
  })

  const generateMutation = useMutation({
    mutationFn: async () => {
      const prevInsight = historyQuery.data?.[0]
      let previousFollowThroughRate: { acted: number; total: number } | undefined
      if (prevInsight) {
        const prevRecs = prevInsight.recommendations?.length
          ? prevInsight.recommendations
          : prevInsight.suggestions ?? []
        const prevActions = actionsQuery.data?.filter(a => a.insight_id === prevInsight.id) ?? []
        const acted = prevActions.filter(a => a.followed).length
        previousFollowThroughRate = {
          acted,
          total: prevRecs.length
        }
      }
      return generateInsight(user!.id, logsQuery.data ?? [], previousFollowThroughRate)
    },
    onSuccess: async (created) => {
      setEnvelopeOpened(false)
      setExpandedInsightId(created.id)
      await queryClient.invalidateQueries({ queryKey: ['insight-history', user?.id] })
      await queryClient.invalidateQueries({ queryKey: ['insight-actions', user?.id] })
    },
  })

  if (!user) return null

  const canGenerate = (logsQuery.data?.length ?? 0) >= 3
  const isPending = generateMutation.isPending
  const currentInsight = generateMutation.data ?? historyQuery.data?.[0] ?? null
  const createdAt = currentInsight?.created_at ? new Date(currentInsight.created_at) : null
  const unlockAt = createdAt ? new Date(createdAt.getTime() + 30 * 24 * 60 * 60 * 1000) : null
  const isFutureLetterLocked = unlockAt ? unlockAt.getTime() > Date.now() : false

  const rawHistory = historyQuery.data ?? []
  const hasMore = rawHistory.length > historyLimit
  const history = rawHistory.slice(0, historyLimit)

  const todayMidnight = new Date()
  todayMidnight.setHours(0, 0, 0, 0)
  const lastGeneratedToday = createdAt
    ? createdAt.getTime() >= todayMidnight.getTime()
    : false
  const isRateLimited = canGenerate && lastGeneratedToday && !generateMutation.data

  const moodDrivers: { label: string; percentage: number }[] = (() => {
    if (!currentInsight) return []
    if (currentInsight.mood_drivers?.length) return currentInsight.mood_drivers
    return parseMoodDriversFromText(currentInsight.prediction)
  })()
  const recommendations = currentInsight?.recommendations?.length
    ? currentInsight.recommendations
    : currentInsight?.suggestions ?? []
  const bestTimeOfDay = currentInsight?.best_time_of_day
    ?? (currentInsight ? inferTimeOfDay(currentInsight.prediction) : null)
    ?? 'Morning'

  const currentInsightActions = actionsQuery.data?.filter(a => a.insight_id === currentInsight?.id) ?? []

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

        <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
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

          {history.length >= 2 && currentInsight && (
            <button
              type="button"
              onClick={() => setCompareOpen(true)}
              style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', background: 'var(--surface-soft)', color: 'var(--text)', border: '1px solid var(--line)' }}
            >
              📊 Compare with previous
            </button>
          )}
        </div>

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
            <div style={{ marginTop: '1.25rem' }}>
              <p className="field-label" style={{ marginBottom: '0.6rem', fontWeight: 600 }}>
                Mood Drivers
              </p>
              <MoodDriversChart drivers={moodDrivers} prediction={currentInsight.prediction} />
            </div>

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
                <RecommendationCards
                  insightId={currentInsight.id}
                  recommendations={recommendations}
                  actions={currentInsightActions}
                  onToggle={(index, followed) => toggleActionMutation.mutate({ insightId: currentInsight.id, index, followed })}
                />
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

            {/* Personal Note */}
            <div style={{ marginTop: '1.25rem' }}>
              <PersonalNoteArea
                insight={currentInsight}
                onSave={async (id, note) => { await saveNoteMutation.mutateAsync({ insightId: id, note }) }}
              />
            </div>
          </>
        )}
      </article>

      {/* Insight History */}
      <article className="card full-width">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem', flexWrap: 'wrap', gap: '0.5rem' }}>
          <h2 style={{ margin: 0 }}>Insight History</h2>
          <div style={{ display: 'flex', gap: '0.5rem' }}>
            <button
              type="button"
              onClick={() => setHistoryView('cards')}
              style={{
                padding: '0.35rem 0.75rem',
                fontSize: '0.82rem',
                background: historyView === 'cards' ? 'var(--brand)' : 'var(--surface-soft)',
                color: historyView === 'cards' ? '#fff' : 'var(--text)',
                border: '1px solid var(--line)'
              }}
            >
              📇 Cards
            </button>
            <button
              type="button"
              onClick={() => setHistoryView('timeline')}
              style={{
                padding: '0.35rem 0.75rem',
                fontSize: '0.82rem',
                background: historyView === 'timeline' ? 'var(--brand)' : 'var(--surface-soft)',
                color: historyView === 'timeline' ? '#fff' : 'var(--text)',
                border: '1px solid var(--line)'
              }}
            >
              ⏳ Timeline
            </button>
          </div>
        </div>

        {historyQuery.isLoading ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.6rem' }}>
            {[1, 2, 3].map((n) => <SkeletonBlock key={n} height={56} />)}
          </div>
        ) : historyView === 'cards' ? (
          <div className="list-stack">
            {history.map((insight) => {
              const expanded = expandedInsightId === insight.id
              const insightRecs = insight.recommendations?.length
                ? insight.recommendations
                : insight.suggestions ?? []
              const actionsForInsight = actionsQuery.data?.filter(a => a.insight_id === insight.id) ?? []

              return (
                <div
                  key={insight.id}
                  className="list-card align-left"
                  style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem', cursor: 'default' }}
                >
                  <button
                    type="button"
                    className="list-card-row"
                    onClick={() => setExpandedInsightId((prev) => (prev === insight.id ? null : insight.id))}
                    aria-expanded={expanded}
                    style={{ background: 'none', border: 'none', padding: 0, width: '100%', cursor: 'pointer', display: 'flex', justifyContent: 'space-between', alignItems: 'center', textAlign: 'left' }}
                  >
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '0.15rem' }}>
                      <strong>{formatDateTime(insight.created_at)}</strong>
                      <FreshnessIndicator createdAt={insight.created_at} />
                    </div>
                    <span style={{ fontSize: '0.85rem', color: 'var(--brand)', fontWeight: 600 }}>
                      {expanded ? 'Hide ▲' : 'Expand ▼'}
                    </span>
                  </button>
                  <p className="muted note-preview" style={{ margin: 0 }}>{insight.prediction.slice(0, 160)}…</p>
                  
                  {expanded && (
                    <div className="expanded-area" style={{ marginTop: '0.75rem', borderTop: '1px solid var(--line)', paddingTop: '0.75rem', display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                      <p style={{ fontSize: '0.9rem', margin: 0 }}>{insight.prediction}</p>
                      
                      {insight.calming_message && (
                        <blockquote className="insight-quote" style={{ margin: 0 }}>{insight.calming_message}</blockquote>
                      )}

                      {insightRecs.length > 0 && (
                        <div>
                          <p className="field-label" style={{ fontWeight: 600, marginBottom: '0.4rem' }}>Recommendations</p>
                          <RecommendationCards
                            insightId={insight.id}
                            recommendations={insightRecs}
                            actions={actionsForInsight}
                            onToggle={(index, followed) => toggleActionMutation.mutate({ insightId: insight.id, index, followed })}
                          />
                        </div>
                      )}
                      
                      <p className="muted" style={{ margin: 0, fontSize: '0.82rem' }}>
                        Future letter preview: {insight.future_letter.slice(0, 120)}…
                      </p>

                      <PersonalNoteArea
                        insight={insight}
                        onSave={async (id, note) => { await saveNoteMutation.mutateAsync({ insightId: id, note }) }}
                      />
                    </div>
                  )}
                </div>
              )
            })}

            {!history.length && <p className="muted">No historical insights yet.</p>}
          </div>
        ) : (
          <div style={{ position: 'relative', paddingLeft: '2rem', borderLeft: '2px solid var(--line)', margin: '1.5rem 0 1.5rem 1rem' }}>
            {history.map((insight) => {
              const moodVal = insight.mood_score ?? 3
              const moodIcon = moodVal >= 4 ? '😊' : moodVal === 3 ? '😐' : '😔'
              const insightRecs = insight.recommendations?.length
                ? insight.recommendations
                : insight.suggestions ?? []
              const actionsForInsight = actionsQuery.data?.filter(a => a.insight_id === insight.id) ?? []

              return (
                <div key={insight.id} style={{ position: 'relative', marginBottom: '2.5rem' }}>
                  {/* Timeline bullet */}
                  <span style={{
                    position: 'absolute',
                    left: 'calc(-2rem - 9px)',
                    top: '4px',
                    width: '16px',
                    height: '16px',
                    borderRadius: '50%',
                    backgroundColor: 'var(--brand)',
                    border: '3px solid var(--surface)'
                  }} />

                  <div style={{ display: 'flex', flexDirection: 'column', gap: '0.6rem' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', flexWrap: 'wrap' }}>
                      <strong style={{ fontSize: '0.95rem' }}>{formatDateTime(insight.created_at)}</strong>
                      <span style={{ fontSize: '0.8rem', background: 'var(--surface-soft)', border: '1px solid var(--line)', padding: '0.2rem 0.5rem', borderRadius: '4px', fontWeight: 600 }}>
                        Mood: {moodIcon} {moodVal}/5
                      </span>
                      <span style={{ fontSize: '0.8rem', background: 'var(--surface-soft)', border: '1px solid var(--line)', padding: '0.2rem 0.5rem', borderRadius: '4px', fontWeight: 600 }}>
                        Stress: ⚠️ {insight.stress_level}/5
                      </span>
                    </div>

                    <p style={{ margin: 0, fontSize: '0.9rem', lineHeight: 1.5 }}>
                      {insight.prediction}
                    </p>

                    {insightRecs.length > 0 && (
                      <div style={{ margin: '0.25rem 0' }}>
                        <RecommendationCards
                          insightId={insight.id}
                          recommendations={insightRecs}
                          actions={actionsForInsight}
                          onToggle={(index, followed) => toggleActionMutation.mutate({ insightId: insight.id, index, followed })}
                        />
                      </div>
                    )}

                    <PersonalNoteArea
                      insight={insight}
                      onSave={async (id, note) => { await saveNoteMutation.mutateAsync({ insightId: id, note }) }}
                    />
                  </div>
                </div>
              )
            })}

            {!history.length && <p className="muted">No historical insights yet.</p>}
          </div>
        )}

        {hasMore && (
          <div style={{ display: 'flex', justifyContent: 'center', marginTop: '1.5rem' }}>
            <button
              type="button"
              onClick={() => setHistoryLimit(prev => prev + 10)}
              style={{ padding: '0.5rem 1.5rem', background: 'var(--surface-soft)', color: 'var(--text)', border: '1px solid var(--line)' }}
            >
              Load more insights
            </button>
          </div>
        )}
      </article>

      {/* Comparison Modal */}
      {compareOpen && history.length >= 2 && (
        <InsightComparisonModal
          latest={history[0]}
          previous={history[1]}
          actions={actionsQuery.data ?? []}
          onClose={() => setCompareOpen(false)}
        />
      )}

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
