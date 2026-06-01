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
