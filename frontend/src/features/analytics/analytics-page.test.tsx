import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { daysAgo } from '../../lib/date'

const mockSupabaseChain = vi.hoisted(() => {
  const chain: {
    select: ReturnType<typeof vi.fn>
    eq: ReturnType<typeof vi.fn>
    gte: ReturnType<typeof vi.fn>
    order: ReturnType<typeof vi.fn>
  } = {
    select: vi.fn(() => chain),
    eq: vi.fn(() => chain),
    gte: vi.fn(() => chain),
    order: vi.fn(),
  }

  chain.order.mockResolvedValue({ data: [], error: null })

  return chain
})

const mockFrom = vi.hoisted(() => vi.fn(() => mockSupabaseChain))

vi.mock('../../lib/supabase', () => ({
  supabase: {
    from: mockFrom,
  },
}))

import {
  buildHabitCorrelation,
  buildHabitFrequency,
  buildHabitMoodHeatmap,
  fetchEntries,
} from './analytics-helpers'

describe('analytics page data helpers', () => {
  beforeEach(() => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2024-04-29T10:30:00.000Z'))

    mockFrom.mockClear()
    mockSupabaseChain.select.mockClear()
    mockSupabaseChain.eq.mockClear()
    mockSupabaseChain.gte.mockClear()
    mockSupabaseChain.order.mockReset()
    mockSupabaseChain.select.mockImplementation(() => mockSupabaseChain)
    mockSupabaseChain.eq.mockImplementation(() => mockSupabaseChain)
    mockSupabaseChain.gte.mockImplementation(() => mockSupabaseChain)
    mockSupabaseChain.order.mockResolvedValue({ data: [], error: null })
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  it('queries the full analytics row shape with an ISO timestamp filter', async () => {
    const rows = [
      {
        id: 'log-1',
        user_id: 'user-1',
        date: '2024-04-26T08:00:00.000Z',
        mood: 5,
        habits: null,
        notes: 'Great day',
        created_at: '2024-04-26T08:00:00.000Z',
        updated_at: '2024-04-26T08:00:00.000Z',
      },
    ]
    mockSupabaseChain.order.mockResolvedValueOnce({ data: rows, error: null })

    const result = await fetchEntries('user-1', 7)

    expect(mockFrom).toHaveBeenCalledWith('log_entries')
    expect(mockSupabaseChain.select).toHaveBeenCalledWith(
      'id, date, mood, habits, notes, user_id, created_at, updated_at',
    )
    expect(mockSupabaseChain.eq).toHaveBeenCalledWith('user_id', 'user-1')
    expect(mockSupabaseChain.gte).toHaveBeenCalledWith('date', daysAgo(7, new Date('2024-04-29T10:30:00.000Z')))
    expect(result).toEqual([
      {
        ...rows[0],
        habits: [],
      },
    ])
  })

  it('handles null habits when building habit charts', () => {
    const entries = [
      {
        id: 'log-1',
        user_id: 'user-1',
        date: '2024-04-26T08:00:00.000Z',
        mood: 5,
        habits: null,
        notes: null,
        created_at: '2024-04-26T08:00:00.000Z',
        updated_at: '2024-04-26T08:00:00.000Z',
      },
      {
        id: 'log-2',
        user_id: 'user-1',
        date: '2024-04-27T08:00:00.000Z',
        mood: 4,
        habits: ['sleep', 'exercise'],
        notes: null,
        created_at: '2024-04-27T08:00:00.000Z',
        updated_at: '2024-04-27T08:00:00.000Z',
      },
    ] as const

    expect(() => buildHabitCorrelation(entries as any)).not.toThrow()
    expect(() => buildHabitFrequency(entries as any)).not.toThrow()

    expect(buildHabitCorrelation(entries as any)).toEqual([
      { habit: 'sleep', count: 1 },
      { habit: 'exercise', count: 1 },
    ])

    expect(buildHabitFrequency(entries as any)).toEqual([
      { habit: 'sleep', count: 1 },
      { habit: 'exercise', count: 1 },
    ])
  })
})

describe('buildHabitMoodHeatmap', () => {
  const makeEntry = (
    mood: number | null,
    habits: string[] | null,
  ) => ({
    id: 'x',
    user_id: 'u',
    date: '2024-01-01',
    mood,
    habits,
    notes: null,
    created_at: '2024-01-01T00:00:00Z',
    updated_at: '2024-01-01T00:00:00Z',
  })

  it('returns empty array for no entries', () => {
    expect(buildHabitMoodHeatmap([])).toEqual([])
  })

  it('returns empty array when all habits are null', () => {
    expect(buildHabitMoodHeatmap([makeEntry(3, null)] as any)).toEqual([])
  })

  it('counts a single habit + single mood correctly', () => {
    const entries = [makeEntry(4, ['exercise']), makeEntry(4, ['exercise'])]
    const result = buildHabitMoodHeatmap(entries as any)
    expect(result).toHaveLength(1)
    expect(result[0].habit).toBe('exercise')
    expect(result[0].counts[4]).toBe(2)
    expect(result[0].counts[1]).toBe(0)
    expect(result[0].counts[5]).toBe(0)
  })

  it('skips entries with null mood', () => {
    const entries = [makeEntry(null, ['walk']), makeEntry(3, ['walk'])]
    const result = buildHabitMoodHeatmap(entries as any)
    expect(result[0].counts[3]).toBe(1)
    // null mood entries should not increment any score
    expect(Object.values(result[0].counts).reduce((a, b) => a + b, 0)).toBe(1)
  })

  it('handles null habits without throwing', () => {
    const entries = [makeEntry(3, null), makeEntry(4, ['run'])]
    expect(() => buildHabitMoodHeatmap(entries as any)).not.toThrow()
    const result = buildHabitMoodHeatmap(entries as any)
    expect(result[0].habit).toBe('run')
    expect(result[0].counts[4]).toBe(1)
  })

  it('selects at most top 10 habits by frequency', () => {
    const habits = Array.from({ length: 15 }, (_, i) => `habit_${i}`)
    // habit_0 appears 15 times, habit_1 14 times, ... habit_14 1 time
    const entries = habits.flatMap((h, i) =>
      Array.from({ length: 15 - i }, () => makeEntry(3, [h])),
    )
    const result = buildHabitMoodHeatmap(entries as any)
    expect(result).toHaveLength(10)
    expect(result[0].habit).toBe('habit_0')
    expect(result[9].habit).toBe('habit_9')
  })

  it('counts multiple habits across mood scores', () => {
    const entries = [
      makeEntry(1, ['sleep', 'exercise']),
      makeEntry(5, ['sleep']),
      makeEntry(5, ['exercise']),
    ]
    const result = buildHabitMoodHeatmap(entries as any)
    const sleep = result.find((r) => r.habit === 'sleep')!
    const exercise = result.find((r) => r.habit === 'exercise')!
    expect(sleep.counts[1]).toBe(1)
    expect(sleep.counts[5]).toBe(1)
    expect(exercise.counts[1]).toBe(1)
    expect(exercise.counts[5]).toBe(1)
  })
})
