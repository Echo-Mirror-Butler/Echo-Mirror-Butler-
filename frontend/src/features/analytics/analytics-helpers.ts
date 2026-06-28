import { daysAgo } from '../../lib/date'
import { supabase } from '../../lib/supabase'
import type { LogEntry } from '../../lib/types'

export type AnalyticsLogEntry = Omit<LogEntry, 'habits'> & {
  habits: string[] | null
}

const DAY_NAMES = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

export async function fetchEntries(userId: string, range: number): Promise<AnalyticsLogEntry[]> {
  const { data, error } = await supabase
    .from('log_entries')
    .select('id, date, mood, habits, notes, user_id, created_at, updated_at')
    .eq('user_id', userId)
    .gte('date', daysAgo(range))
    .order('date', { ascending: true })

  if (error) throw error
  return (data ?? []).map((entry) => ({
    ...entry,
    habits: Array.isArray(entry.habits) ? entry.habits : [],
  })) as AnalyticsLogEntry[]
}

export function buildMoodTrend(entries: AnalyticsLogEntry[]): { date: string; mood: number }[] {
  return entries
    .filter((e) => e.mood != null)
    .map((e) => ({ date: e.date.slice(5), mood: e.mood as number }))
}

export function buildMoodDistribution(entries: AnalyticsLogEntry[]): { mood: string; count: number }[] {
  const counts: Record<number, number> = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 }
  for (const e of entries) {
    if (e.mood != null) {
      counts[e.mood] = (counts[e.mood] ?? 0) + 1
    }
  }
  return Object.entries(counts).map(([mood, count]) => ({ mood, count }))
}

export function buildBestDayOfWeek(entries: AnalyticsLogEntry[]): { day: string; avg: number }[] {
  const daySums: Record<number, { sum: number; count: number }> = {}
  for (const e of entries) {
    if (e.mood == null) continue
    const day = new Date(e.date).getDay()
    if (!daySums[day]) daySums[day] = { sum: 0, count: 0 }
    daySums[day].sum += e.mood
    daySums[day].count += 1
  }
  return DAY_NAMES.map((day, i) => ({
    day,
    avg: daySums[i] ? +(daySums[i].sum / daySums[i].count).toFixed(2) : 0,
  }))
}

export function buildHabitCorrelation(entries: AnalyticsLogEntry[]): { habit: string; count: number }[] {
  const highMoodEntries = entries.filter((e) => e.mood != null && e.mood >= 4)
  const freq: Record<string, number> = {}
  for (const e of highMoodEntries) {
    for (const h of e.habits ?? []) {
      freq[h] = (freq[h] ?? 0) + 1
    }
  }
  return Object.entries(freq)
    .map(([habit, count]) => ({ habit, count }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 8)
}

export function buildHabitFrequency(entries: AnalyticsLogEntry[]): { habit: string; count: number }[] {
  const freq: Record<string, number> = {}
  for (const e of entries) {
    for (const h of e.habits ?? []) {
      freq[h] = (freq[h] ?? 0) + 1
    }
  }
  return Object.entries(freq)
    .map(([habit, count]) => ({ habit, count }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 8)
}

export function buildStreakDays(entries: AnalyticsLogEntry[]): Set<string> {
  return new Set(entries.map((e) => e.date.slice(0, 10)))
}

export type HeatmapRow = { habit: string; counts: Record<number, number> }

export function buildHabitMoodHeatmap(entries: AnalyticsLogEntry[]): HeatmapRow[] {
  const freq: Record<string, number> = {}
  for (const e of entries) {
    for (const h of e.habits ?? []) freq[h] = (freq[h] ?? 0) + 1
  }
  const topHabits = Object.entries(freq)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10)
    .map(([h]) => h)

  if (topHabits.length === 0) return []

  const grid: Record<string, Record<number, number>> = {}
  for (const h of topHabits) grid[h] = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 }

  for (const e of entries) {
    if (e.mood == null) continue
    for (const h of e.habits ?? []) {
      if (grid[h]) grid[h][e.mood] = (grid[h][e.mood] ?? 0) + 1
    }
  }

  return topHabits.map((h) => ({ habit: h, counts: grid[h] }))
}
