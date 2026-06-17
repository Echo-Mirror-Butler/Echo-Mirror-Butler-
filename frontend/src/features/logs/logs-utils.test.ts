import { describe, expect, test } from 'vitest'
import { isSortOption, splitOnMatch } from './logs-utils'

describe('isSortOption', () => {
  test('accepts the four valid sort values', () => {
    expect(isSortOption('date_desc')).toBe(true)
    expect(isSortOption('date_asc')).toBe(true)
    expect(isSortOption('mood_desc')).toBe(true)
    expect(isSortOption('mood_asc')).toBe(true)
  })

  test('rejects unknown or malformed values', () => {
    expect(isSortOption('mood')).toBe(false)
    expect(isSortOption(null)).toBe(false)
    expect(isSortOption(undefined)).toBe(false)
    expect(isSortOption(42)).toBe(false)
  })
})

describe('splitOnMatch', () => {
  test('returns a single non-matching segment when the term is empty', () => {
    expect(splitOnMatch('hello world', '')).toEqual([{ text: 'hello world', match: false }])
  })

  test('marks a case-insensitive match', () => {
    const segments = splitOnMatch('I went Running today', 'running')
    expect(segments).toEqual([
      { text: 'I went ', match: false },
      { text: 'Running', match: true },
      { text: ' today', match: false },
    ])
  })

  test('marks every occurrence of the term', () => {
    const segments = splitOnMatch('run run run', 'run')
    expect(segments.filter((s) => s.match)).toHaveLength(3)
  })

  test('escapes regex special characters in the term', () => {
    const segments = splitOnMatch('cost is $5 today', '$5')
    expect(segments).toContainEqual({ text: '$5', match: true })
  })

  test('handles a term that does not appear', () => {
    expect(splitOnMatch('nothing here', 'xyz')).toEqual([{ text: 'nothing here', match: false }])
  })
})
