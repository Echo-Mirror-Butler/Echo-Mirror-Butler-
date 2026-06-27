import type { LogEntry } from '../../lib/types'

/**
 * Columns emitted by the logs CSV export, in order. The header row uses these
 * exact names.
 */
export const LOG_CSV_COLUMNS = ['id', 'date', 'mood', 'habits', 'notes', 'created_at'] as const

/** The minimal shape needed to build a CSV row for a log entry. */
export type LogCsvRow = Pick<LogEntry, 'id' | 'date' | 'mood' | 'habits' | 'notes' | 'created_at'>

/**
 * Escape a single CSV field per RFC 4180: wrap the value in double quotes when
 * it contains a comma, double quote, or line break, and escape inner quotes by
 * doubling them.
 */
export function escapeCsvField(value: string): string {
  if (/[",\n\r]/.test(value)) {
    return `"${value.replace(/"/g, '""')}"`
  }
  return value
}

/**
 * Serialize one log entry to a CSV row. Habits are joined into a
 * semicolon-separated string instead of being JSON-stringified, and a `null`
 * mood/notes becomes an empty field.
 */
export function logEntryToCsvRow(entry: LogCsvRow): string {
  const habits = Array.isArray(entry.habits) ? entry.habits : []
  const fields = [
    entry.id,
    entry.date,
    entry.mood ?? '',
    habits.join('; '),
    entry.notes ?? '',
    entry.created_at,
  ]
  return fields.map((field) => escapeCsvField(String(field))).join(',')
}

/** Build a complete CSV document (header row + one row per entry). */
export function buildLogsCsv(entries: LogCsvRow[]): string {
  const header = LOG_CSV_COLUMNS.join(',')
  const rows = entries.map(logEntryToCsvRow)
  return [header, ...rows].join('\n')
}
