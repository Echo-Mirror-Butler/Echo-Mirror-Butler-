export type AchievementId =
  | 'first_log'
  | 'week_warrior'
  | 'month_master'
  | 'century'
  | 'insight_seeker'
  | 'echo_gifter'
  | 'habit_hero'
  | 'global_citizen'

export type AchievementDef = {
  id: AchievementId
  name: string
  description: string
  hint: string
  icon: string
  echoReward: number
}

export const HABIT_HERO_RUN = 10

export const ACHIEVEMENTS: AchievementDef[] = [
  {
    id: 'first_log',
    name: 'First Log',
    description: 'Log your first mood entry',
    hint: 'Log a mood to get started',
    icon: '\u{1F331}',
    echoReward: 0,
  },
  {
    id: 'week_warrior',
    name: 'Week Warrior',
    description: '7-day logging streak',
    hint: 'Log your mood 7 days in a row',
    icon: '\u{1F525}',
    echoReward: 10,
  },
  {
    id: 'month_master',
    name: 'Month Master',
    description: '30-day logging streak',
    hint: 'Log your mood 30 days in a row',
    icon: '\u{1F31F}',
    echoReward: 50,
  },
  {
    id: 'century',
    name: 'Century',
    description: '100-day logging streak',
    hint: 'Log your mood 100 days in a row',
    icon: '\u{1F4AF}',
    echoReward: 200,
  },
  {
    id: 'insight_seeker',
    name: 'Insight Seeker',
    description: 'Generate your first AI insight',
    hint: 'Visit AI Insights and generate one',
    icon: '\u2728',
    echoReward: 0,
  },
  {
    id: 'echo_gifter',
    name: 'ECHO Gifter',
    description: 'Send ECHO to another user',
    hint: 'Send a gift from your wallet',
    icon: '\u{1F381}',
    echoReward: 0,
  },
  {
    id: 'habit_hero',
    name: 'Habit Hero',
    description: `Log the same habit ${HABIT_HERO_RUN} days in a row`,
    hint: `Track one habit for ${HABIT_HERO_RUN} consecutive days`,
    icon: '\u{1F4AA}',
    echoReward: 0,
  },
  {
    id: 'global_citizen',
    name: 'Global Citizen',
    description: 'Drop a pin on the Global Mirror',
    hint: 'Share your mood on the world map',
    icon: '\u{1F4CD}',
    echoReward: 0,
  },
]

export type AchievementProgress = {
  logCount: number
  currentStreak: number
  insightCount: number
  giftsSent: number
  maxHabitRun: number
}

const DAY_MS = 24 * 60 * 60 * 1000

// Longest run of consecutive days on which the same habit was logged.
// log_entries stores habits as a jsonb array of habit names per entry.
export function maxConsecutiveHabitDays(
  rows: { date: string; habits: string[] }[],
): number {
  const daysByHabit = new Map<string, Set<number>>()

  for (const row of rows) {
    const time = Date.parse(row.date)
    if (Number.isNaN(time)) continue
    const day = Math.floor(time / DAY_MS)
    for (const habit of row.habits) {
      let days = daysByHabit.get(habit)
      if (!days) {
        days = new Set()
        daysByHabit.set(habit, days)
      }
      days.add(day)
    }
  }

  let best = 0
  for (const days of daysByHabit.values()) {
    const sorted = [...days].sort((a, b) => a - b)
    let run = 1
    for (let i = 0; i < sorted.length; i += 1) {
      if (i > 0 && sorted[i] === sorted[i - 1] + 1) {
        run += 1
      } else {
        run = 1
      }
      if (run > best) best = run
    }
  }
  return best
}

// Consecutive UTC days with at least one log, counting back from today
// (or yesterday, so the streak survives until the current day is missed).
// Computed from log_entries because the get_current_streak RPC reads
// mood_logs, a table nothing in the app writes to.
export function currentLoggingStreak(dates: string[], now = Date.now()): number {
  const days = new Set<number>()
  for (const date of dates) {
    const time = Date.parse(date)
    if (Number.isNaN(time)) continue
    days.add(Math.floor(time / DAY_MS))
  }

  const today = Math.floor(now / DAY_MS)
  let day = days.has(today) ? today : today - 1
  let streak = 0
  while (days.has(day)) {
    streak += 1
    day -= 1
  }
  return streak
}

// global_citizen is not derivable from queryable data (mood pins are
// anonymous), so it is unlocked directly when the user drops a pin.
export function evaluateAchievements(progress: AchievementProgress): AchievementId[] {
  const earned: AchievementId[] = []
  if (progress.logCount >= 1) earned.push('first_log')
  if (progress.currentStreak >= 7) earned.push('week_warrior')
  if (progress.currentStreak >= 30) earned.push('month_master')
  if (progress.currentStreak >= 100) earned.push('century')
  if (progress.insightCount >= 1) earned.push('insight_seeker')
  if (progress.giftsSent >= 1) earned.push('echo_gifter')
  if (progress.maxHabitRun >= HABIT_HERO_RUN) earned.push('habit_hero')
  return earned
}
