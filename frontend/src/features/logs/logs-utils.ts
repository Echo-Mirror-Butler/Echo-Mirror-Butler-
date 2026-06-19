/** Available sort orders for the logs list. */
export type SortOption = 'date_desc' | 'date_asc' | 'mood_desc' | 'mood_asc'

/** Sort options in display order; the first entry is the default. */
export const SORT_OPTIONS: { value: SortOption; label: string }[] = [
  { value: 'date_desc', label: 'Date (newest first)' },
  { value: 'date_asc', label: 'Date (oldest first)' },
  { value: 'mood_desc', label: 'Mood (highest)' },
  { value: 'mood_asc', label: 'Mood (lowest)' },
]

export const DEFAULT_SORT: SortOption = 'date_desc'

/** Type guard for values read back from storage / the DOM. */
export function isSortOption(value: unknown): value is SortOption {
  return (
    value === 'date_desc' ||
    value === 'date_asc' ||
    value === 'mood_desc' ||
    value === 'mood_asc'
  )
}

/** A run of text that either matches the search term or does not. */
export type HighlightSegment = { text: string; match: boolean }

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

/**
 * Split `text` into alternating non-matching / matching segments for the given
 * search `term` (case-insensitive). Used to highlight matches in the notes
 * preview. Returns a single non-matching segment when the term is empty.
 */
export function splitOnMatch(text: string, term: string): HighlightSegment[] {
  const trimmed = term.trim()
  if (!trimmed || !text) {
    return [{ text, match: false }]
  }

  const matcher = new RegExp(escapeRegExp(trimmed), 'gi')
  const segments: HighlightSegment[] = []
  let lastIndex = 0
  let found: RegExpExecArray | null

  while ((found = matcher.exec(text)) !== null) {
    if (found.index > lastIndex) {
      segments.push({ text: text.slice(lastIndex, found.index), match: false })
    }
    segments.push({ text: found[0], match: true })
    lastIndex = found.index + found[0].length

    // Guard against zero-length matches creating an infinite loop.
    if (found.index === matcher.lastIndex) {
      matcher.lastIndex += 1
    }
  }

  if (lastIndex < text.length) {
    segments.push({ text: text.slice(lastIndex), match: false })
  }

  return segments
}
