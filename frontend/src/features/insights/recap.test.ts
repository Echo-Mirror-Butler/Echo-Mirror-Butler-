import { describe, it, expect } from 'vitest'
import {
  computeRecap,
  hasSufficientHistory,
  longestStreak,
  periodStart,
  type RecapInput,
} from './recap'

function iso(daysAgo: number, now = new Date('2026-07-25T12:00:00Z')): string {
  return new Date(now.getTime() - daysAgo * 86_400_000).toISOString()
}

const NOW = new Date('2026-07-25T12:00:00Z')

describe('hasSufficientHistory', () => {
  it('requires >= 30 logs', () => {
    expect(hasSufficientHistory(29, iso(60), NOW)).toBe(false)
    expect(hasSufficientHistory(30, iso(60), NOW)).toBe(true)
  })
  it('requires >= 30 days since signup', () => {
    expect(hasSufficientHistory(50, iso(10), NOW)).toBe(false)
    expect(hasSufficientHistory(50, iso(31), NOW)).toBe(true)
  })
  it('rejects missing / invalid signup date', () => {
    expect(hasSufficientHistory(50, null, NOW)).toBe(false)
    expect(hasSufficientHistory(50, 'not-a-date', NOW)).toBe(false)
  })
})

describe('longestStreak', () => {
  it('counts consecutive calendar days once per day', () => {
    const logs = [
      { date: '2026-07-01', mood: 3, habits: [] },
      { date: '2026-07-02', mood: 3, habits: [] },
      { date: '2026-07-02', mood: 4, habits: [] }, // same day, no double count
      { date: '2026-07-03', mood: 3, habits: [] },
      { date: '2026-07-06', mood: 3, habits: [] }, // gap resets
      { date: '2026-07-07', mood: 3, habits: [] },
    ]
    expect(longestStreak(logs)).toBe(3)
  })
  it('returns 0 for no logs', () => {
    expect(longestStreak([])).toBe(0)
  })
})

describe('periodStart', () => {
  it('is null for all-time', () => {
    expect(periodStart('all_time', NOW)).toBeNull()
  })
  it('goes back a month / year', () => {
    expect(periodStart('last_month', NOW)?.toISOString().slice(0, 10)).toBe('2026-06-25')
    expect(periodStart('last_year', NOW)?.toISOString().slice(0, 10)).toBe('2025-07-25')
  })
})

describe('computeRecap', () => {
  const input: RecapInput = {
    logs: [
      { date: iso(2), mood: 5, habits: ['Exercise', 'Sleep'] },
      { date: iso(3), mood: 4, habits: ['Exercise'] },
      { date: iso(4), mood: 3, habits: ['Reading'] },
      { date: iso(400), mood: 1, habits: ['Exercise'] }, // outside last_year
    ],
    echoTransactions: [
      { amount: 10, direction: 'earned', date: iso(2) },
      { amount: 50, direction: 'earned', date: iso(3) },
      { amount: 15, direction: 'spent', date: iso(2) },
    ],
    achievements: [
      { achievement_id: 'week_warrior', unlocked_at: iso(2) },
      { achievement_id: 'century', unlocked_at: iso(500) }, // outside last_year
    ],
  }

  it('aggregates all-time totals', () => {
    const r = computeRecap(input, 'all_time', NOW)
    expect(r.totalLogs).toBe(4)
    expect(r.echoEarned).toBe(60)
    expect(r.echoSpent).toBe(15)
    expect(r.achievementsUnlocked).toBe(2)
    expect(r.topHabits[0]).toEqual({ habit: 'Exercise', count: 3 })
  })

  it('filters by period window', () => {
    const r = computeRecap(input, 'last_year', NOW)
    expect(r.totalLogs).toBe(3) // the 400-days-ago log excluded
    expect(r.achievementsUnlocked).toBe(1) // 500-days-ago achievement excluded
  })

  it('computes avg mood and highlights', () => {
    const r = computeRecap(input, 'last_year', NOW)
    expect(r.avgMood).toBe(4) // (5+4+3)/3
    expect(r.highlights.bestDay?.mood).toBe(5)
    expect(r.longestStreak).toBe(3) // days -2,-3,-4 consecutive
    expect(r.highlights.mostActiveMonth).not.toBeNull()
  })

  it('handles empty input safely', () => {
    const r = computeRecap({ logs: [], echoTransactions: [], achievements: [] }, 'all_time', NOW)
    expect(r.totalLogs).toBe(0)
    expect(r.avgMood).toBeNull()
    expect(r.moodTrend).toBeNull()
    expect(r.highlights.bestDay).toBeNull()
  })
})
