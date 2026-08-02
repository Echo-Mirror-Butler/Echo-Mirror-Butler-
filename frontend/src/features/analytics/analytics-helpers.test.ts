import { describe, it, expect } from 'vitest'
import { buildHabitStreaks, predictTomorrowMood, type AnalyticsLogEntry } from './analytics-helpers'

describe('buildHabitStreaks', () => {
  it('calculates current and longest streaks correctly', () => {
    const today = new Date()
    today.setUTCHours(0, 0, 0, 0)
    const yesterday = new Date(today.getTime() - 86400000)
    const yesterdayStr = yesterday.toISOString().slice(0, 10)
    const twoDaysAgo = new Date(today.getTime() - 2 * 86400000)
    const threeDaysAgo = new Date(today.getTime() - 3 * 86400000)

    const entries: AnalyticsLogEntry[] = [
      {
        id: '1',
        date: threeDaysAgo.toISOString().slice(0, 10),
        mood: 3,
        habits: ['Exercise'],
        notes: '',
        user_id: 'user1',
        created_at: '',
        updated_at: '',
      },
      {
        id: '2',
        date: twoDaysAgo.toISOString().slice(0, 10),
        mood: 4,
        habits: ['Exercise'],
        notes: '',
        user_id: 'user1',
        created_at: '',
        updated_at: '',
      },
      {
        id: '3',
        date: yesterdayStr,
        mood: 4,
        habits: ['Exercise'],
        notes: '',
        user_id: 'user1',
        created_at: '',
        updated_at: '',
      },
    ]

    const result = buildHabitStreaks(entries)
    expect(result).toHaveLength(1)
    expect(result[0].habit).toBe('Exercise')
    expect(result[0].currentStreak).toBe(3)
    expect(result[0].longestStreak).toBe(3)
  })

  it('breaks streak when habit is skipped', () => {
    const today = new Date()
    today.setUTCHours(0, 0, 0, 0)
    const monStr = today.toISOString().slice(0, 10)
    const tueStr = new Date(today.getTime() + 86400000).toISOString().slice(0, 10)
    const wedStr = new Date(today.getTime() + 2 * 86400000).toISOString().slice(0, 10)
    const friStr = new Date(today.getTime() + 4 * 86400000).toISOString().slice(0, 10)

    const entries: AnalyticsLogEntry[] = [
      {
        id: '1',
        date: monStr,
        mood: 3,
        habits: ['Exercise'],
        notes: '',
        user_id: 'user1',
        created_at: '',
        updated_at: '',
      },
      {
        id: '2',
        date: tueStr,
        mood: 4,
        habits: ['Exercise'],
        notes: '',
        user_id: 'user1',
        created_at: '',
        updated_at: '',
      },
      {
        id: '3',
        date: wedStr,
        mood: 4,
        habits: ['Exercise'],
        notes: '',
        user_id: 'user1',
        created_at: '',
        updated_at: '',
      },
      {
        id: '4',
        date: friStr,
        mood: 4,
        habits: ['Exercise'],
        notes: '',
        user_id: 'user1',
        created_at: '',
        updated_at: '',
      },
    ]

    const result = buildHabitStreaks(entries)
    expect(result[0].longestStreak).toBe(3)
    expect(result[0].currentStreak).toBe(0)
  })

  it('returns empty array when no entries', () => {
    const result = buildHabitStreaks([])
    expect(result).toEqual([])
  })

  it('sets current streak to 0 when last logged is older than yesterday', () => {
    const today = new Date()
    today.setUTCHours(0, 0, 0, 0)
    const threeDaysAgo = new Date(today.getTime() - 3 * 86400000)
    const twoDaysAgo = new Date(today.getTime() - 2 * 86400000)

    const entries: AnalyticsLogEntry[] = [
      {
        id: '1',
        date: threeDaysAgo.toISOString().slice(0, 10),
        mood: 3,
        habits: ['Exercise'],
        notes: '',
        user_id: 'user1',
        created_at: '',
        updated_at: '',
      },
      {
        id: '2',
        date: twoDaysAgo.toISOString().slice(0, 10),
        mood: 4,
        habits: ['Exercise'],
        notes: '',
        user_id: 'user1',
        created_at: '',
        updated_at: '',
      },
    ]

    const result = buildHabitStreaks(entries)
    expect(result[0].currentStreak).toBe(0)
    expect(result[0].longestStreak).toBe(2)
  })
})

describe('predictTomorrowMood', () => {
  it('returns null for empty entries', () => {
    expect(predictTomorrowMood([])).toBeNull()
  })

  it('returns low confidence with single sample', () => {
    const today = new Date()
    today.setUTCHours(0, 0, 0, 0)
    const tomorrow = new Date(today)
    tomorrow.setDate(tomorrow.getDate() + 1)
    const sampleDate = new Date(tomorrow)
    sampleDate.setDate(sampleDate.getDate() - 7)

    // Need to adjust so they share the same weekday as tomorrow
    while (sampleDate.getDay() !== tomorrow.getDay()) {
      sampleDate.setDate(sampleDate.getDate() + 1)
    }

    const entries: AnalyticsLogEntry[] = [
      {
        id: '1',
        date: sampleDate.toISOString().slice(0, 10),
        mood: 4,
        habits: ['Exercise'],
        notes: '',
        user_id: 'user1',
        created_at: '',
        updated_at: '',
      },
    ]

    const result = predictTomorrowMood(entries)
    expect(result).not.toBeNull()
    expect(result!.confidence).toBe('low')
    expect(result!.predicted).toBeGreaterThanOrEqual(1)
    expect(result!.predicted).toBeLessThanOrEqual(5)
  })

  it('returns medium confidence with 4-7 samples', () => {
    const today = new Date()
    today.setUTCHours(0, 0, 0, 0)
    const tomorrow = new Date(today)
    tomorrow.setDate(tomorrow.getDate() + 1)

    const entries: AnalyticsLogEntry[] = []
    for (let i = 0; i < 5; i++) {
      const d = new Date(tomorrow)
      d.setDate(d.getDate() - (i + 1) * 7)
      const dateStr = d.toISOString().slice(0, 10)
      entries.push({
        id: `${i}`,
        date: dateStr,
        mood: 3 + (i % 3),
        habits: [],
        notes: '',
        user_id: 'user1',
        created_at: '',
        updated_at: '',
      })
    }

    const result = predictTomorrowMood(entries)
    expect(result).not.toBeNull()
    expect(result!.confidence).toBe('medium')
  })

  it('returns high confidence with 8+ samples', () => {
    const today = new Date()
    today.setUTCHours(0, 0, 0, 0)
    const tomorrow = new Date(today)
    tomorrow.setDate(tomorrow.getDate() + 1)

    const entries: AnalyticsLogEntry[] = []
    for (let i = 0; i < 9; i++) {
      const d = new Date(tomorrow)
      d.setDate(d.getDate() - (i + 1) * 7)
      const dateStr = d.toISOString().slice(0, 10)
      entries.push({
        id: `${i}`,
        date: dateStr,
        mood: 4,
        habits: [],
        notes: '',
        user_id: 'user1',
        created_at: '',
        updated_at: '',
      })
    }

    const result = predictTomorrowMood(entries)
    expect(result).not.toBeNull()
    expect(result!.confidence).toBe('high')
    expect(result!.reason).toContain('tend to feel')
  })
})
