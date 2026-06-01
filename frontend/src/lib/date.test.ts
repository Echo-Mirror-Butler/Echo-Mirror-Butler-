import { describe, it, expect } from 'vitest'
import { formatDate, formatDateTime, moodToEmoji, getCountdownLabel, toDateInputValue, daysAgo } from './date'

describe('formatDate', () => {
  it('formats ISO string to readable date', () => {
    const result = formatDate('2024-04-29T10:30:00.000Z')
    expect(result).toMatch(/Apr 29, 2024/)
  })

  it('handles different date formats', () => {
    const result = formatDate('2024-12-25T15:45:00.000Z')
    expect(result).toMatch(/Dec 25, 2024/)
  })

  it('handles invalid dates gracefully', () => {
    expect(() => formatDate('invalid-date')).toThrow('Invalid time value')
  })
})

describe('formatDateTime', () => {
  it('formats ISO string to readable date with time', () => {
    const result = formatDateTime('2024-04-29T10:30:00.000Z')
    expect(result).toMatch(/Apr 29, 2024/)
    expect(result).toMatch(/AM|PM/)
  })

  it('includes time component', () => {
    const result = formatDateTime('2024-04-29T14:45:30.000Z')
    expect(result).toMatch(/PM/)
  })

  it('handles invalid dates gracefully', () => {
    expect(() => formatDateTime('invalid-date')).toThrow('Invalid time value')
  })
})

describe('daysAgo', () => {
  it('returns a full ISO timestamp instead of a date-only string', () => {
    const baseDate = new Date('2024-04-29T10:30:00.000Z')
    const result = daysAgo(7, baseDate)

    expect(result).toBe('2024-04-22T10:30:00.000Z')
    expect(result).toMatch(/T\d{2}:\d{2}:\d{2}\.\d{3}Z$/)
  })
})

describe('moodToEmoji', () => {
  it('returns correct emoji for moods 1-5', () => {
    expect(moodToEmoji(1)).toBe('😞')
    expect(moodToEmoji(2)).toBe('😕')
    expect(moodToEmoji(3)).toBe('😐')
    expect(moodToEmoji(4)).toBe('🙂')
    expect(moodToEmoji(5)).toBe('😄')
  })

  it('handles null mood gracefully', () => {
    expect(moodToEmoji(null)).toBe('—')
  })

  it('handles 0 and 6 gracefully', () => {
    expect(moodToEmoji(0)).toBe('—')
    expect(moodToEmoji(6)).toBe('—')
  })

  it('handles negative numbers gracefully', () => {
    expect(moodToEmoji(-1)).toBe('—')
  })
})

describe('getCountdownLabel', () => {
  beforeEach(() => {
    // Mock current time for consistent testing
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2024-04-29T10:00:00.000Z'))
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  it('returns "X days Y hours left" for multi-day distances', () => {
    const target = new Date('2024-05-01T15:00:00.000Z').toISOString()
    const result = getCountdownLabel(target)
    expect(result).toBe('2d 5h left')
  })

  it('returns "X hours Y minutes left" for same-day distances', () => {
    const target = new Date('2024-04-29T14:30:00.000Z').toISOString()
    const result = getCountdownLabel(target)
    expect(result).toBe('4h 30m left')
  })

  it('handles minutes only', () => {
    const target = new Date('2024-04-29T10:45:00.000Z').toISOString()
    const result = getCountdownLabel(target)
    expect(result).toBe('0h 45m left')
  })

  it('handles past dates (returns 0h 0m left)', () => {
    const target = new Date('2024-04-29T09:00:00.000Z').toISOString()
    const result = getCountdownLabel(target)
    expect(result).toBe('0h 0m left')
  })
})

describe('toDateInputValue', () => {
  it('returns YYYY-MM-DD format for given Date', () => {
    const date = new Date('2024-04-29T10:30:00.000Z')
    const result = toDateInputValue(date)
    expect(result).toBe('2024-04-29')
  })

  it('pads single digit month and day with zero', () => {
    const date = new Date('2024-01-05T10:30:00.000Z')
    const result = toDateInputValue(date)
    expect(result).toBe('2024-01-05')
  })

  it('handles leap year dates', () => {
    const date = new Date('2024-02-29T10:30:00.000Z')
    const result = toDateInputValue(date)
    expect(result).toBe('2024-02-29')
  })

  it('handles end of year dates', () => {
    const date = new Date('2024-12-31T10:30:00.000Z')
    const result = toDateInputValue(date)
    expect(result).toBe('2024-12-31')
  })
})
