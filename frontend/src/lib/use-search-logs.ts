import { useEffect, useMemo, useState, useRef } from 'react'
import { supabase } from './supabase'
import type { LogEntry } from './types'

export interface SearchResult extends Pick<LogEntry, 'id' | 'date' | 'mood' | 'notes'> {}

const DEBOUNCE_MS = 300

function parseQuery(raw: string): { text: string; moodFilter: number | null } {
  const trimmed = raw.trim()
  const moodMatch = trimmed.match(/mood:(\d)\b/i)
  if (!moodMatch) return { text: trimmed, moodFilter: null }

  const moodFilter = Number(moodMatch[1])
  const text = trimmed.replace(/mood:\d\b/i, '').trim()
  return { text, moodFilter }
}

export function useSearchLogs(userId: string | undefined, query: string) {
  const [results, setResults] = useState<SearchResult[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const debounceTimer = useRef<ReturnType<typeof setTimeout>>(undefined)

  const { text, moodFilter } = useMemo(() => parseQuery(query), [query])

  useEffect(() => {
    if (debounceTimer.current) {
      clearTimeout(debounceTimer.current)
    }

    if (!userId || (!text && moodFilter === null)) {
      setResults([])
      return
    }

    setIsLoading(true)
    debounceTimer.current = setTimeout(async () => {
      try {
        let builder = supabase
          .from('log_entries')
          .select('id, date, mood, notes, habits')
          .eq('user_id', userId)
          .limit(8)

        if (text) {
          builder = builder.or(`notes.ilike.%${text}%,habits::text.ilike.%${text}%`)
        }

        if (moodFilter !== null) {
          builder = builder.eq('mood', moodFilter)
        }

        builder = builder.order('date', { ascending: false })

        const { data, error } = await builder

        if (error) {
          console.error('Search error:', error)
          setResults([])
        } else {
          setResults(data as SearchResult[])
        }
      } catch (err) {
        console.error('Search failed:', err)
        setResults([])
      } finally {
        setIsLoading(false)
      }
    }, DEBOUNCE_MS)

    return () => {
      if (debounceTimer.current) {
        clearTimeout(debounceTimer.current)
      }
    }
  }, [userId, text, moodFilter])

  return { results, isLoading }
}
