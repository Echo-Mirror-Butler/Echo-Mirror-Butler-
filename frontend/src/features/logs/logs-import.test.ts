import { describe, expect, test } from 'vitest'
import {
  normalizeImportDate,
  parseHabits,
  parseLogsCsv,
  parseLogsJson,
  parseMood,
  splitCsvLine,
  toImportRpcPayload,
} from './logs-import'
import { buildLogsCsv } from './logs-csv'

describe('normalizeImportDate', () => {
  test('accepts YYYY-MM-DD', () => {
    expect(normalizeImportDate('2026-06-01')).toBe('2026-06-01')
  })

  test('accepts ISO timestamps', () => {
    expect(normalizeImportDate('2026-06-01T12:00:00.000Z')).toBe('2026-06-01')
  })

  test('rejects garbage', () => {
    expect(normalizeImportDate('not-a-date')).toBeNull()
    expect(normalizeImportDate('')).toBeNull()
  })
})

describe('parseMood', () => {
  test('accepts 1-5', () => {
    expect(parseMood(3)).toBe(3)
    expect(parseMood('5')).toBe(5)
  })

  test('null for empty', () => {
    expect(parseMood('')).toBeNull()
    expect(parseMood(null)).toBeNull()
  })

  test('invalid outside range', () => {
    expect(parseMood(0)).toBe('invalid')
    expect(parseMood(6)).toBe('invalid')
    expect(parseMood('x')).toBe('invalid')
  })
})

describe('parseHabits', () => {
  test('splits semicolon-separated export format', () => {
    expect(parseHabits('Exercise; Reading')).toEqual(['Exercise', 'Reading'])
  })

  test('accepts arrays', () => {
    expect(parseHabits(['a', 'b'])).toEqual(['a', 'b'])
  })
})

describe('splitCsvLine', () => {
  test('handles quoted commas', () => {
    expect(splitCsvLine('a,"b,c",d')).toEqual(['a', 'b,c', 'd'])
  })

  test('handles escaped quotes', () => {
    expect(splitCsvLine('"she said ""hi"""')).toEqual(['she said "hi"'])
  })
})

describe('parseLogsCsv', () => {
  test('round-trips export CSV', () => {
    const csv = buildLogsCsv([
      {
        id: 'log-1',
        date: '2026-06-01T12:00:00.000Z',
        mood: 4,
        habits: ['Exercise', 'Reading'],
        notes: 'Felt great',
        created_at: '2026-06-01T13:00:00.000Z',
      },
    ])
    const preview = parseLogsCsv(csv)
    expect(preview.invalid).toHaveLength(0)
    expect(preview.uniqueValid).toHaveLength(1)
    expect(preview.uniqueValid[0]).toMatchObject({
      date: '2026-06-01',
      mood: 4,
      habits: ['Exercise', 'Reading'],
      notes: 'Felt great',
    })
  })

  test('rejects missing date column', () => {
    const preview = parseLogsCsv('mood,notes\n4,hi')
    expect(preview.invalid[0]?.error).toMatch(/date/i)
  })

  test('flags bad mood rows', () => {
    const preview = parseLogsCsv('date,mood\n2026-06-01,9')
    expect(preview.invalid).toHaveLength(1)
    expect(preview.invalid[0]?.error).toMatch(/Mood/)
  })

  test('dedupes same date within file', () => {
    const preview = parseLogsCsv(
      'date,mood\n2026-06-01,3\n2026-06-01,5\n2026-06-02,4',
    )
    expect(preview.valid).toHaveLength(3)
    expect(preview.uniqueValid).toHaveLength(2)
  })
})

describe('parseLogsJson', () => {
  test('accepts plain array', () => {
    const preview = parseLogsJson(
      JSON.stringify([{ date: '2026-06-01', mood: 2, habits: [], notes: null }]),
    )
    expect(preview.uniqueValid).toHaveLength(1)
    expect(preview.uniqueValid[0].mood).toBe(2)
  })

  test('accepts export-user-data shape', () => {
    const preview = parseLogsJson(
      JSON.stringify({
        data: { moodLogs: [{ date: '2026-07-01', mood: 5, habits: ['Walk'] }] },
      }),
    )
    expect(preview.uniqueValid).toHaveLength(1)
    expect(preview.uniqueValid[0].habits).toEqual(['Walk'])
  })

  test('rejects invalid JSON', () => {
    const preview = parseLogsJson('{not json')
    expect(preview.invalid[0]?.error).toMatch(/Invalid JSON/)
  })
})

describe('toImportRpcPayload', () => {
  test('maps fields for RPC', () => {
    expect(
      toImportRpcPayload([{ date: '2026-01-01', mood: 1, habits: ['a'], notes: 'n' }]),
    ).toEqual([{ date: '2026-01-01', mood: 1, habits: ['a'], notes: 'n' }])
  })
})
