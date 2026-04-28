import { useEffect, useState, useRef } from 'react'
import { supabase } from './supabase'
import type { LogEntry } from './types'

export interface SearchResult extends Pick<LogEntry, 'id' | 'date' | 'mood' | 'notes'> {}

const DEBOUNCE_MS = 300

export function useSearchLogs(userId: string | undefined, query: string) {
  const [results, setResults] = useState<SearchResult[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const debounceTimer = useRef<NodeJS.Timeout>()

  useEffect(() => {
    if (debounceTimer.current) {
      clearTimeout(debounceTimer.current)
    }

    if (!userId || !query.trim()) {
      setResults([])
      return
    }

    setIsLoading(true)
    debounceTimer.current = setTimeout(async () => {
      try {
        const { data, error } = await supabase
          .from('log_entries')
          .select('id, date, mood, notes, habits')
          .eq('user_id', userId)
          .or(`notes.ilike.%${query}%,habits::text.ilike.%${query}%`)
          .order('date', { ascending: false })
          .limit(8)

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
  }, [userId, query])

  return { results, isLoading }
}
