import { useEffect, useMemo, useState, useRef } from 'react'
import { supabase } from './supabase'
import type { LogEntry, Insight } from './types'

export interface SearchResult {
  type: 'log' | 'insight' | 'person'
  id: string
  title: string
  subtitle: string
  link: string
}

const DEBOUNCE_MS = 300

export function useUnifiedSearch(userId: string | undefined, query: string) {
  const [results, setResults] = useState<SearchResult[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const debounceTimer = useRef<ReturnType<typeof setTimeout>>(undefined)

  const trimmed = useMemo(() => query.trim(), [query])

  useEffect(() => {
    if (debounceTimer.current) clearTimeout(debounceTimer.current)

    if (!userId || !trimmed) {
      setResults([])
      return
    }

    setIsLoading(true)
    debounceTimer.current = setTimeout(async () => {
      try {
        const text = trimmed.replace(/mood:\d\b/i, '').trim()
        const moodMatch = trimmed.match(/mood:(\d)\b/i)
        const moodFilter = moodMatch ? Number(moodMatch[1]) : null

        const [logsRes, insightsRes, peopleRes] = await Promise.all([
          (async () => {
            let b = supabase
              .from('log_entries')
              .select('id, date, mood, notes')
              .eq('user_id', userId)
              .limit(5)
            if (text) b = b.or(`notes.ilike.%${text}%,habits::text.ilike.%${text}%`)
            if (moodFilter !== null) b = b.eq('mood', moodFilter)
            b = b.order('date', { ascending: false })
            const { data } = await b
            return ((data ?? []) as LogEntry[]).map((e) => ({
              type: 'log' as const,
              id: e.id,
              title: `Mood ${e.mood ?? '?'} — ${new Date(e.date).toLocaleDateString()}`,
              subtitle: e.notes ? e.notes.substring(0, 80) : 'No notes',
              link: `/logs/${e.id}/edit`,
            }))
          })(),
          (async () => {
            const { data } = await supabase
              .from('ai_insights')
              .select('id, prediction, created_at')
              .eq('user_id', userId)
              .order('created_at', { ascending: false })
              .limit(5)
            return ((data ?? []) as Insight[]).map((e) => ({
              type: 'insight' as const,
              id: e.id,
              title: `Insight — ${new Date(e.created_at).toLocaleDateString()}`,
              subtitle: e.prediction.substring(0, 80),
              link: '/insights',
            }))
          })(),
          (async () => {
            const { data } = await supabase
              .from('profiles')
              .select('id, display_name, avatar_url')
              .ilike('display_name', `%${text}%`)
              .neq('id', userId)
              .limit(5)
            return ((data ?? []) as { id: string; display_name: string | null }[]).map((e) => ({
              type: 'person' as const,
              id: e.id,
              title: e.display_name ?? 'User',
              subtitle: 'Person',
              link: `/global-mirror`,
            }))
          })(),
        ])

        const all: SearchResult[] = [...logsRes, ...insightsRes, ...peopleRes]
        setResults(all.slice(0, 12))
      } catch {
        setResults([])
      } finally {
        setIsLoading(false)
      }
    }, DEBOUNCE_MS)

    return () => {
      if (debounceTimer.current) clearTimeout(debounceTimer.current)
    }
  }, [userId, trimmed])

  const grouped = useMemo(() => {
    const groups: { type: string; label: string; items: SearchResult[] }[] = []
    const byType = new Map<string, SearchResult[]>()
    for (const r of results) {
      const arr = byType.get(r.type) ?? []
      arr.push(r)
      byType.set(r.type, arr)
    }
    if (byType.has('log')) groups.push({ type: 'log', label: 'Logs', items: byType.get('log')! })
    if (byType.has('insight')) groups.push({ type: 'insight', label: 'Insights', items: byType.get('insight')! })
    if (byType.has('person')) groups.push({ type: 'person', label: 'People', items: byType.get('person')! })
    return groups
  }, [results])

  return { results, grouped, isLoading }
}
