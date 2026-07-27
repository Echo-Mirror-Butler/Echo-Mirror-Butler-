/**
 * recap.ts — Issue #617 (Year in Review / periodic recap)
 *
 * Pure, side-effect-free aggregation for a personal recap summary. Kept
 * separate from rendering/sharing so it is unit-testable in isolation.
 *
 * PLATFORM SCOPE: this recap feature is intentionally implemented on the web
 * frontend only for this change (no Flutter toolchain available to verify a
 * Dart port). See the PR notes / issue #617's own fallback instruction.
 *
 * Input rows use the real database column shapes:
 *   - log_entries: { date, mood (1–5 | null), habits: string[] }
 *   - echo transactions: normalized to { amount, direction, date } by the page
 *     (earned ← echo_rewards, spent ← gift_transactions.sender)
 *   - user_achievements: { achievement_id, unlocked_at }
 */

export type RecapPeriod = 'last_month' | 'last_year' | 'all_time'

export type RecapLogEntry = {
  date: string // ISO timestamp or YYYY-MM-DD
  mood: number | null
  habits: string[]
}

export type RecapEchoTxn = {
  amount: number
  direction: 'earned' | 'spent'
  date: string
}

export type RecapAchievement = {
  achievement_id: string
  unlocked_at: string
}

export type RecapInput = {
  logs: RecapLogEntry[]
  echoTransactions: RecapEchoTxn[]
  achievements: RecapAchievement[]
}

export type RecapHighlight = {
  bestDay: { date: string; mood: number } | null
  mostActiveMonth: { month: string; logs: number } | null
}

export type Recap = {
  period: RecapPeriod
  totalLogs: number
  avgMood: number | null
  /** Difference between the avg mood of the later vs earlier half of the period. */
  moodTrend: number | null
  longestStreak: number
  topHabits: { habit: string; count: number }[]
  echoEarned: number
  echoSpent: number
  achievementsUnlocked: number
  highlights: RecapHighlight
}

// ── Gating ────────────────────────────────────────────────────────────────

export const MIN_LOGS_FOR_RECAP = 30
export const MIN_DAYS_SINCE_SIGNUP = 30

/**
 * Recap is only meaningful with enough history. Requires at least
 * MIN_LOGS_FOR_RECAP logs AND at least MIN_DAYS_SINCE_SIGNUP days since signup.
 */
export function hasSufficientHistory(
  logCount: number,
  signupDate: string | Date | null | undefined,
  now: Date = new Date(),
): boolean {
  if (logCount < MIN_LOGS_FOR_RECAP) return false
  if (!signupDate) return false
  const signup = signupDate instanceof Date ? signupDate : new Date(signupDate)
  if (Number.isNaN(signup.getTime())) return false
  const days = (now.getTime() - signup.getTime()) / 86_400_000
  return days >= MIN_DAYS_SINCE_SIGNUP
}

// ── Helpers ───────────────────────────────────────────────────────────────

/** Start Date (inclusive) for a period, or null for all-time. */
export function periodStart(period: RecapPeriod, now: Date = new Date()): Date | null {
  if (period === 'all_time') return null
  const start = new Date(now)
  if (period === 'last_month') start.setMonth(start.getMonth() - 1)
  else start.setFullYear(start.getFullYear() - 1)
  return start
}

function dayKey(iso: string): string {
  return iso.slice(0, 10)
}

function monthKey(iso: string): string {
  return iso.slice(0, 7) // YYYY-MM
}

function inRange(iso: string, start: Date | null, now: Date): boolean {
  const t = new Date(iso).getTime()
  if (Number.isNaN(t)) return false
  if (t > now.getTime()) return false
  if (start && t < start.getTime()) return false
  return true
}

/** Longest run of consecutive calendar days that have at least one log. */
export function longestStreak(logs: RecapLogEntry[]): number {
  const days = [...new Set(logs.map((l) => dayKey(l.date)))].sort()
  if (days.length === 0) return 0
  let longest = 1
  let run = 1
  for (let i = 1; i < days.length; i += 1) {
    const prev = new Date(days[i - 1] + 'T00:00:00Z').getTime()
    const cur = new Date(days[i] + 'T00:00:00Z').getTime()
    const diffDays = Math.round((cur - prev) / 86_400_000)
    if (diffDays === 1) {
      run += 1
      longest = Math.max(longest, run)
    } else {
      run = 1
    }
  }
  return longest
}

function round1(n: number): number {
  return Math.round(n * 10) / 10
}

function average(nums: number[]): number | null {
  if (nums.length === 0) return null
  return round1(nums.reduce((a, b) => a + b, 0) / nums.length)
}

// ── Main aggregation ────────────────────────────────────────────────────────

export function computeRecap(
  input: RecapInput,
  period: RecapPeriod = 'all_time',
  now: Date = new Date(),
): Recap {
  const start = periodStart(period, now)

  const logs = input.logs.filter((l) => inRange(l.date, start, now))
  const echo = input.echoTransactions.filter((e) => inRange(e.date, start, now))
  const achievements = input.achievements.filter((a) => inRange(a.unlocked_at, start, now))

  const moods = logs.filter((l) => l.mood != null).map((l) => l.mood as number)
  const avgMood = average(moods)

  // Mood trend: later half avg minus earlier half avg (chronological).
  let moodTrend: number | null = null
  const moodPoints = logs
    .filter((l) => l.mood != null)
    .slice()
    .sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime())
    .map((l) => l.mood as number)
  if (moodPoints.length >= 2) {
    const mid = Math.floor(moodPoints.length / 2)
    const first = average(moodPoints.slice(0, mid))
    const second = average(moodPoints.slice(mid))
    if (first != null && second != null) moodTrend = round1(second - first)
  }

  // Top habits.
  const habitCounts = new Map<string, number>()
  for (const l of logs) {
    for (const h of l.habits ?? []) {
      habitCounts.set(h, (habitCounts.get(h) ?? 0) + 1)
    }
  }
  const topHabits = [...habitCounts.entries()]
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, 5)
    .map(([habit, count]) => ({ habit, count }))

  const echoEarned = echo
    .filter((e) => e.direction === 'earned')
    .reduce((s, e) => s + e.amount, 0)
  const echoSpent = echo
    .filter((e) => e.direction === 'spent')
    .reduce((s, e) => s + e.amount, 0)

  // Highlights: best day (highest single-log mood, earliest wins on tie) and
  // most active month (most logs).
  let bestDay: RecapHighlight['bestDay'] = null
  for (const l of logs) {
    if (l.mood == null) continue
    if (!bestDay || l.mood > bestDay.mood) {
      bestDay = { date: dayKey(l.date), mood: l.mood }
    }
  }

  const monthCounts = new Map<string, number>()
  for (const l of logs) {
    const k = monthKey(l.date)
    monthCounts.set(k, (monthCounts.get(k) ?? 0) + 1)
  }
  let mostActiveMonth: RecapHighlight['mostActiveMonth'] = null
  for (const [month, count] of monthCounts.entries()) {
    if (!mostActiveMonth || count > mostActiveMonth.logs) {
      mostActiveMonth = { month, logs: count }
    }
  }

  return {
    period,
    totalLogs: logs.length,
    avgMood,
    moodTrend,
    longestStreak: longestStreak(logs),
    topHabits,
    echoEarned: Math.round(echoEarned),
    echoSpent: Math.round(echoSpent),
    achievementsUnlocked: achievements.length,
    highlights: { bestDay, mostActiveMonth },
  }
}

export const PERIOD_LABELS: Record<RecapPeriod, string> = {
  last_month: 'Last month',
  last_year: 'Last year',
  all_time: 'All time',
}
