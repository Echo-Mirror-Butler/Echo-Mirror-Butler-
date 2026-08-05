import { describe, it, expect } from 'vitest'
import {
  parseHHMM,
  isWithinQuietWindow,
  isInQuietHours,
  formatHHMM,
  type QuietHoursPrefs,
} from './quiet-hours'

describe('parseHHMM', () => {
  it('parses valid times to minutes-since-midnight', () => {
    expect(parseHHMM('00:00')).toBe(0)
    expect(parseHHMM('08:30')).toBe(510)
    expect(parseHHMM('22:00')).toBe(1320)
    expect(parseHHMM('23:59')).toBe(1439)
  })

  it('returns NaN for invalid input', () => {
    expect(parseHHMM('')).toBeNaN()
    expect(parseHHMM('24:00')).toBeNaN()
    expect(parseHHMM('12:60')).toBeNaN()
    expect(parseHHMM('nope')).toBeNaN()
  })
})

describe('isWithinQuietWindow', () => {
  it('handles a same-day window (01:00 → 06:00)', () => {
    const start = parseHHMM('01:00')
    const end = parseHHMM('06:00')
    expect(isWithinQuietWindow(parseHHMM('00:30'), start, end)).toBe(false)
    expect(isWithinQuietWindow(parseHHMM('01:00'), start, end)).toBe(true) // inclusive start
    expect(isWithinQuietWindow(parseHHMM('03:00'), start, end)).toBe(true)
    expect(isWithinQuietWindow(parseHHMM('06:00'), start, end)).toBe(false) // exclusive end
    expect(isWithinQuietWindow(parseHHMM('09:00'), start, end)).toBe(false)
  })

  it('handles a wrap-around window (22:00 → 08:00)', () => {
    const start = parseHHMM('22:00')
    const end = parseHHMM('08:00')
    expect(isWithinQuietWindow(parseHHMM('23:30'), start, end)).toBe(true)
    expect(isWithinQuietWindow(parseHHMM('00:00'), start, end)).toBe(true)
    expect(isWithinQuietWindow(parseHHMM('07:59'), start, end)).toBe(true)
    expect(isWithinQuietWindow(parseHHMM('08:00'), start, end)).toBe(false)
    expect(isWithinQuietWindow(parseHHMM('12:00'), start, end)).toBe(false)
    expect(isWithinQuietWindow(parseHHMM('21:59'), start, end)).toBe(false)
  })

  it('treats start === end as an empty window (never quiet)', () => {
    const t = parseHHMM('09:00')
    expect(isWithinQuietWindow(t, t, t)).toBe(false)
  })
})

describe('isInQuietHours', () => {
  const base: QuietHoursPrefs = {
    quietHoursEnabled: true,
    quietHoursStart: '22:00',
    quietHoursEnd: '08:00',
    moodCommentDigestMode: 'immediately',
  }

  function at(hhmm: string): Date {
    const [h, m] = hhmm.split(':').map(Number)
    const d = new Date()
    d.setHours(h, m, 0, 0)
    return d
  }

  it('returns false when quiet hours are disabled', () => {
    expect(isInQuietHours({ ...base, quietHoursEnabled: false }, at('23:00'))).toBe(false)
  })

  it('returns true inside the window and false outside', () => {
    expect(isInQuietHours(base, at('23:00'))).toBe(true)
    expect(isInQuietHours(base, at('03:00'))).toBe(true)
    expect(isInQuietHours(base, at('12:00'))).toBe(false)
  })
})

describe('formatHHMM', () => {
  it('formats to a locale time string', () => {
    // Exact locale formatting varies; just assert it produced something with digits.
    expect(formatHHMM('22:00')).toMatch(/\d/)
  })

  it('passes through invalid values unchanged', () => {
    expect(formatHHMM('nope')).toBe('nope')
  })
})
