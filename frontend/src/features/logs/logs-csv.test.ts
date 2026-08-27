import { describe, expect, test } from 'vitest'
import { buildLogsCsv, escapeCsvField, logEntryToCsvRow, LOG_CSV_COLUMNS } from './logs-csv'
import type { LogCsvRow } from './logs-csv'

const baseEntry: LogCsvRow = {
  id: 'log-1',
  date: '2026-06-01T12:00:00.000Z',
  mood: 4,
  habits: ['Exercise', 'Reading'],
  notes: 'Felt great today',
  created_at: '2026-06-01T13:00:00.000Z',
}

describe('escapeCsvField', () => {
  test('leaves plain values untouched', () => {
    expect(escapeCsvField('hello')).toBe('hello')
  })

  test('quotes values containing a comma', () => {
    expect(escapeCsvField('a,b')).toBe('"a,b"')
  })

  test('escapes embedded double quotes by doubling them', () => {
    expect(escapeCsvField('she said "hi"')).toBe('"she said ""hi"""')
  })

  test('quotes values containing newlines', () => {
    expect(escapeCsvField('line1\nline2')).toBe('"line1\nline2"')
  })
})

describe('logEntryToCsvRow', () => {
  test('joins habits with a semicolon instead of JSON-stringifying', () => {
    const row = logEntryToCsvRow(baseEntry)
    expect(row).toContain('Exercise; Reading')
    expect(row).not.toContain('[')
    expect(row).not.toContain('"Exercise"')
  })

  test('includes the id and created_at columns', () => {
    const row = logEntryToCsvRow(baseEntry)
    expect(row.startsWith('log-1,')).toBe(true)
    expect(row).toContain('2026-06-01T13:00:00.000Z')
  })

  test('renders null mood and notes as empty fields', () => {
    const row = logEntryToCsvRow({ ...baseEntry, mood: null, notes: null })
    expect(row).toBe('log-1,2026-06-01T12:00:00.000Z,,Exercise; Reading,,2026-06-01T13:00:00.000Z')
  })

  test('escapes notes that contain commas', () => {
    const row = logEntryToCsvRow({ ...baseEntry, notes: 'one, two, three' })
    expect(row).toContain('"one, two, three"')
  })

  test('tolerates a non-array habits value', () => {
    const row = logEntryToCsvRow({ ...baseEntry, habits: undefined as unknown as string[] })
    expect(row).toContain('log-1,')
  })
})

describe('buildLogsCsv', () => {
  test('emits a header row with the expected column names', () => {
    const csv = buildLogsCsv([])
    expect(csv).toBe(LOG_CSV_COLUMNS.join(','))
    expect(csv).toBe('id,date,mood,habits,notes,created_at')
  })

  test('produces one line per entry plus the header', () => {
    const csv = buildLogsCsv([baseEntry, { ...baseEntry, id: 'log-2' }])
    const lines = csv.split('\n')
    expect(lines).toHaveLength(3)
    expect(lines[0]).toBe('id,date,mood,habits,notes,created_at')
    expect(lines[1].startsWith('log-1,')).toBe(true)
    expect(lines[2].startsWith('log-2,')).toBe(true)
  })
})
