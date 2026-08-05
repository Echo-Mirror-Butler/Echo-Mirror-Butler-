/**
 * Issue #636: CSV/JSON bulk import for mood logs (log_entries).
 * Mirrors the export schema in logs-csv.ts.
 */

export type ImportRow = {
  date: string
  mood: number | null
  habits: string[]
  notes: string | null
}

export type ImportRowResult =
  | { ok: true; row: number; data: ImportRow }
  | { ok: false; row: number; error: string; raw?: string }

export type ImportPreview = {
  valid: ImportRowResult[]
  invalid: ImportRowResult[]
  /** Valid rows after dropping duplicates within the file (by calendar day). */
  uniqueValid: ImportRow[]
}

const MAX_NOTES = 2000
const MAX_ROWS = 500

/** Normalize a date string to YYYY-MM-DD (UTC calendar day). */
export function normalizeImportDate(value: string): string | null {
  const trimmed = value.trim()
  if (!trimmed) return null

  // Already YYYY-MM-DD
  if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) {
    const d = new Date(`${trimmed}T12:00:00.000Z`)
    if (Number.isNaN(d.getTime())) return null
    return trimmed
  }

  const d = new Date(trimmed)
  if (Number.isNaN(d.getTime())) return null
  return d.toISOString().slice(0, 10)
}

export function parseMood(value: unknown): number | null | 'invalid' {
  if (value === null || value === undefined || value === '') return null
  const n = typeof value === 'number' ? value : Number(String(value).trim())
  if (!Number.isInteger(n) || n < 1 || n > 5) return 'invalid'
  return n
}

export function parseHabits(value: unknown): string[] {
  if (Array.isArray(value)) {
    return value.map((h) => String(h).trim()).filter(Boolean)
  }
  if (typeof value === 'string' && value.trim()) {
    return value
      .split(/;/)
      .map((h) => h.trim())
      .filter(Boolean)
  }
  return []
}

/** RFC 4180-ish CSV line splitter that respects quoted fields. */
export function splitCsvLine(line: string): string[] {
  const fields: string[] = []
  let current = ''
  let inQuotes = false

  for (let i = 0; i < line.length; i += 1) {
    const ch = line[i]
    if (inQuotes) {
      if (ch === '"') {
        if (line[i + 1] === '"') {
          current += '"'
          i += 1
        } else {
          inQuotes = false
        }
      } else {
        current += ch
      }
    } else if (ch === '"') {
      inQuotes = true
    } else if (ch === ',') {
      fields.push(current)
      current = ''
    } else {
      current += ch
    }
  }
  fields.push(current)
  return fields
}

function headerIndexMap(headerFields: string[]): Record<string, number> {
  const map: Record<string, number> = {}
  headerFields.forEach((raw, i) => {
    const key = raw.trim().toLowerCase().replace(/^\uFEFF/, '')
    map[key] = i
  })
  return map
}

function validateRow(
  rowNum: number,
  dateRaw: unknown,
  moodRaw: unknown,
  habitsRaw: unknown,
  notesRaw: unknown,
): ImportRowResult {
  const date = normalizeImportDate(String(dateRaw ?? ''))
  if (!date) {
    return { ok: false, row: rowNum, error: 'Missing or invalid date' }
  }

  const mood = parseMood(moodRaw)
  if (mood === 'invalid') {
    return { ok: false, row: rowNum, error: 'Mood must be an integer 1–5' }
  }

  const habits = parseHabits(habitsRaw)
  let notes: string | null =
    notesRaw === null || notesRaw === undefined || notesRaw === ''
      ? null
      : String(notesRaw)
  if (notes !== null) {
    notes = notes.trim() || null
  }
  if (notes && notes.length > MAX_NOTES) {
    return { ok: false, row: rowNum, error: `Notes exceed ${MAX_NOTES} characters` }
  }

  return {
    ok: true,
    row: rowNum,
    data: { date, mood, habits, notes },
  }
}

export function parseLogsCsv(text: string): ImportPreview {
  const lines = text
    .replace(/^\uFEFF/, '')
    .split(/\r?\n/)
    .filter((l) => l.trim().length > 0)

  if (lines.length === 0) {
    return { valid: [], invalid: [{ ok: false, row: 0, error: 'Empty file' }], uniqueValid: [] }
  }

  const header = splitCsvLine(lines[0])
  const idx = headerIndexMap(header)

  if (idx.date === undefined) {
    return {
      valid: [],
      invalid: [{ ok: false, row: 1, error: 'CSV must include a "date" column' }],
      uniqueValid: [],
    }
  }

  const dataLines = lines.slice(1)
  if (dataLines.length > MAX_ROWS) {
    return {
      valid: [],
      invalid: [
        {
          ok: false,
          row: 0,
          error: `Maximum ${MAX_ROWS} rows per import (file has ${dataLines.length})`,
        },
      ],
      uniqueValid: [],
    }
  }

  const valid: ImportRowResult[] = []
  const invalid: ImportRowResult[] = []

  dataLines.forEach((line, i) => {
    const fields = splitCsvLine(line)
    const result = validateRow(
      i + 2, // 1-based including header
      fields[idx.date],
      idx.mood !== undefined ? fields[idx.mood] : '',
      idx.habits !== undefined ? fields[idx.habits] : '',
      idx.notes !== undefined ? fields[idx.notes] : '',
    )
    if (result.ok) valid.push(result)
    else invalid.push(result)
  })

  return finalizePreview(valid, invalid)
}

export function parseLogsJson(text: string): ImportPreview {
  let parsed: unknown
  try {
    parsed = JSON.parse(text)
  } catch {
    return {
      valid: [],
      invalid: [{ ok: false, row: 0, error: 'Invalid JSON' }],
      uniqueValid: [],
    }
  }

  let rows: unknown[]
  if (Array.isArray(parsed)) {
    rows = parsed
  } else if (parsed && typeof parsed === 'object') {
    const obj = parsed as Record<string, unknown>
    // export-user-data shape: { data: { moodLogs: [...] } } or { moodLogs: [...] }
    const nested =
      (obj.data as Record<string, unknown> | undefined)?.moodLogs ??
      (obj.data as Record<string, unknown> | undefined)?.log_entries ??
      obj.moodLogs ??
      obj.log_entries ??
      obj.logs
    if (Array.isArray(nested)) {
      rows = nested
    } else {
      return {
        valid: [],
        invalid: [
          {
            ok: false,
            row: 0,
            error: 'JSON must be an array of log objects or { data: { moodLogs: [...] } }',
          },
        ],
        uniqueValid: [],
      }
    }
  } else {
    return {
      valid: [],
      invalid: [{ ok: false, row: 0, error: 'JSON must be an array of objects' }],
      uniqueValid: [],
    }
  }

  if (rows.length > MAX_ROWS) {
    return {
      valid: [],
      invalid: [
        {
          ok: false,
          row: 0,
          error: `Maximum ${MAX_ROWS} rows per import (file has ${rows.length})`,
        },
      ],
      uniqueValid: [],
    }
  }

  const valid: ImportRowResult[] = []
  const invalid: ImportRowResult[] = []

  rows.forEach((item, i) => {
    if (!item || typeof item !== 'object') {
      invalid.push({ ok: false, row: i + 1, error: 'Row is not an object' })
      return
    }
    const r = item as Record<string, unknown>
    const result = validateRow(i + 1, r.date, r.mood, r.habits, r.notes)
    if (result.ok) valid.push(result)
    else invalid.push(result)
  })

  return finalizePreview(valid, invalid)
}

function finalizePreview(
  valid: ImportRowResult[],
  invalid: ImportRowResult[],
): ImportPreview {
  const seen = new Set<string>()
  const uniqueValid: ImportRow[] = []
  for (const item of valid) {
    if (!item.ok) continue
    if (seen.has(item.data.date)) continue
    seen.add(item.data.date)
    uniqueValid.push(item.data)
  }
  return { valid, invalid, uniqueValid }
}

export function parseImportFile(filename: string, text: string): ImportPreview {
  const lower = filename.toLowerCase()
  if (lower.endsWith('.json')) return parseLogsJson(text)
  return parseLogsCsv(text)
}

/** Payload shape accepted by public.import_log_entries */
export function toImportRpcPayload(rows: ImportRow[]): unknown[] {
  return rows.map((r) => ({
    date: r.date,
    mood: r.mood,
    habits: r.habits,
    notes: r.notes,
  }))
}
