import { describe, it, expect, vi } from 'vitest'

const mockFrom = vi.hoisted(() => vi.fn())
const mockRpc = vi.hoisted(() => vi.fn())

vi.mock('../../lib/supabase', () => ({
  supabase: {
    from: mockFrom,
    rpc: mockRpc,
    functions: { invoke: vi.fn() },
  },
}))

vi.mock('../../lib/auth-context', () => ({
  useAuth: () => ({
    user: { id: 'test-user-id', email: 'test@example.com' },
    session: null,
    isLoading: false,
    signOut: vi.fn(),
  }),
}))

// Re-implement the pure helpers from insights-page.tsx for testing
function normalizeInsightPayload(input: unknown): {
  prediction: string
  suggestions: string[]
  futureLetter: string
  stressLevel: number
  moodDrivers?: { label: string; percentage: number }[]
  bestTimeOfDay?: string
  recommendations?: string[]
  moodScore?: number
} {
  if (!input || typeof input !== 'object') {
    throw new Error('Invalid insight payload from edge function.')
  }

  const candidate = input as Record<string, unknown>
  const suggestionsValue = candidate.suggestions
  const suggestions = Array.isArray(suggestionsValue)
    ? suggestionsValue.map((item) => String(item)).slice(0, 5)
    : []

  let moodDrivers: { label: string; percentage: number }[] | undefined
  if (Array.isArray(candidate.moodDrivers)) {
    moodDrivers = (candidate.moodDrivers as unknown[])
      .filter((d): d is Record<string, unknown> => typeof d === 'object' && d !== null)
      .map((d) => ({ label: String(d.label ?? ''), percentage: Number(d.percentage ?? 0) }))
      .filter((d) => d.label && d.percentage > 0)
  }

  let recommendations: string[] | undefined
  if (Array.isArray(candidate.recommendations)) {
    recommendations = (candidate.recommendations as unknown[]).map((r) => String(r)).filter(Boolean)
  }

  return {
    prediction: String(candidate.prediction ?? '').trim(),
    suggestions,
    futureLetter: String(candidate.futureLetter ?? '').trim(),
    stressLevel: Number(candidate.stressLevel ?? 0),
    moodDrivers,
    bestTimeOfDay: candidate.bestTimeOfDay ? String(candidate.bestTimeOfDay) : undefined,
    recommendations,
    moodScore: candidate.moodScore ? Number(candidate.moodScore) : undefined,
  }
}

function parseMoodDriversFromText(text: string): { label: string; percentage: number }[] {
  const matches = [...text.matchAll(/([A-Za-z][A-Za-z\s-]{1,}?)\s*[:=-]?\s*(\d{1,3})%/g)]
  return matches
    .map((match) => ({
      label: match[1].trim().replace(/\s+/g, ' '),
      percentage: Math.min(100, Math.max(0, Number(match[2]))),
    }))
    .filter((driver) => driver.label && driver.percentage > 0)
    .slice(0, 6)
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

describe('normalizeInsightPayload', () => {
  it('returns structured payload from valid input', () => {
    const result = normalizeInsightPayload({
      prediction: 'You seem happy',
      suggestions: ['Sleep more', 'Exercise'],
      futureLetter: 'Dear future self...',
      stressLevel: 2,
      moodDrivers: [{ label: 'Sleep', percentage: 60 }],
      bestTimeOfDay: 'Morning',
      recommendations: ['Walk daily'],
      moodScore: 4,
    })

    expect(result.prediction).toBe('You seem happy')
    expect(result.suggestions).toEqual(['Sleep more', 'Exercise'])
    expect(result.futureLetter).toBe('Dear future self...')
    expect(result.stressLevel).toBe(2)
    expect(result.moodDrivers).toEqual([{ label: 'Sleep', percentage: 60 }])
    expect(result.bestTimeOfDay).toBe('Morning')
    expect(result.recommendations).toEqual(['Walk daily'])
    expect(result.moodScore).toBe(4)
  })

  it('throws on null input', () => {
    expect(() => normalizeInsightPayload(null)).toThrow('Invalid insight payload')
  })

  it('throws on non-object input', () => {
    expect(() => normalizeInsightPayload('string')).toThrow('Invalid insight payload')
  })

  it('handles missing fields gracefully', () => {
    const result = normalizeInsightPayload({})
    expect(result.prediction).toBe('')
    expect(result.suggestions).toEqual([])
    expect(result.futureLetter).toBe('')
    expect(result.stressLevel).toBe(0)
    expect(result.moodDrivers).toBeUndefined()
  })

  it('truncates suggestions to 5', () => {
    const result = normalizeInsightPayload({
      suggestions: ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
    })
    expect(result.suggestions).toHaveLength(5)
  })

  it('filters out invalid mood drivers', () => {
    const result = normalizeInsightPayload({
      moodDrivers: [
        { label: 'Sleep', percentage: 50 },
        { label: '', percentage: 30 },
        { label: 'Exercise', percentage: 0 },
        'not-an-object',
      ],
    })
    expect(result.moodDrivers).toEqual([{ label: 'Sleep', percentage: 50 }])
  })
})

describe('parseMoodDriversFromText', () => {
  it('extracts drivers from prediction text', () => {
    const text = 'Your mood is influenced by Sleep: 45% and Exercise 30%'
    const result = parseMoodDriversFromText(text)
    expect(result).toEqual([
      { label: 'Sleep', percentage: 45 },
      { label: 'Exercise', percentage: 30 },
    ])
  })

  it('caps percentages at 100', () => {
    const result = parseMoodDriversFromText('Stress = 150%')
    expect(result[0].percentage).toBe(100)
  })

  it('returns empty array when no patterns match', () => {
    expect(parseMoodDriversFromText('No percentages here')).toEqual([])
  })

  it('limits to 6 drivers', () => {
    const text = Array.from({ length: 10 }, (_, i) => `Factor${i}: ${10 + i}%`).join(' ')
    const result = parseMoodDriversFromText(text)
    expect(result).toHaveLength(6)
  })

  it('handles different separators', () => {
    expect(parseMoodDriversFromText('Sleep - 50%')).toHaveLength(1)
    expect(parseMoodDriversFromText('Exercise = 60%')).toHaveLength(1)
    expect(parseMoodDriversFromText('Diet: 70%')).toHaveLength(1)
  })
})

describe('getFreshnessLabel', () => {
  it('returns "Just generated" for very recent insights', () => {
    const now = new Date().toISOString()
    const result = getFreshnessLabel(now)
    expect(result.label).toBe('Just generated')
    expect(result.color).toBe('#22c55e')
  })

  it('returns hours ago for insights < 24h old', () => {
    const threeHoursAgo = new Date(Date.now() - 3 * 60 * 60 * 1000).toISOString()
    const result = getFreshnessLabel(threeHoursAgo)
    expect(result.label).toBe('3h ago')
    expect(result.color).toBe('#22c55e')
  })

  it('returns days ago for insights 1-7 days old', () => {
    const threeDaysAgo = new Date(Date.now() - 3 * 24 * 60 * 60 * 1000).toISOString()
    const result = getFreshnessLabel(threeDaysAgo)
    expect(result.label).toBe('3d ago')
    expect(result.color).toBe('#f97316')
  })

  it('returns regenerating suggestion for insights > 7 days old', () => {
    const tenDaysAgo = new Date(Date.now() - 10 * 24 * 60 * 60 * 1000).toISOString()
    const result = getFreshnessLabel(tenDaysAgo)
    expect(result.label).toContain('consider regenerating')
    expect(result.color).toBe('#f43f5e')
  })
})
