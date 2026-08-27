import { describe, expect, test } from 'vitest'
import {
  ACHIEVEMENTS,
  currentLoggingStreak,
  evaluateAchievements,
  maxConsecutiveHabitDays,
  type AchievementProgress,
} from './achievements'

const baseProgress: AchievementProgress = {
  logCount: 0,
  currentStreak: 0,
  insightCount: 0,
  giftsSent: 0,
  maxHabitRun: 0,
}

describe('ACHIEVEMENTS', () => {
  test('defines all 8 badges with unique ids', () => {
    expect(ACHIEVEMENTS).toHaveLength(8)
    expect(new Set(ACHIEVEMENTS.map((entry) => entry.id)).size).toBe(8)
  })

  test('streak milestones carry the specified ECHO rewards', () => {
    const rewardById = Object.fromEntries(
      ACHIEVEMENTS.map((entry) => [entry.id, entry.echoReward]),
    )
    expect(rewardById.week_warrior).toBe(10)
    expect(rewardById.month_master).toBe(50)
    expect(rewardById.century).toBe(200)
  })
})

describe('evaluateAchievements', () => {
  test('returns nothing for a brand new user', () => {
    expect(evaluateAchievements(baseProgress)).toEqual([])
  })

  test('unlocks first_log after one entry', () => {
    expect(evaluateAchievements({ ...baseProgress, logCount: 1 })).toEqual(['first_log'])
  })

  test('streak milestones unlock cumulatively', () => {
    expect(evaluateAchievements({ ...baseProgress, logCount: 7, currentStreak: 7 })).toEqual([
      'first_log',
      'week_warrior',
    ])
    expect(
      evaluateAchievements({ ...baseProgress, logCount: 100, currentStreak: 100 }),
    ).toEqual(['first_log', 'week_warrior', 'month_master', 'century'])
  })

  test('insight, gift, and habit achievements come from their own counters', () => {
    expect(
      evaluateAchievements({ ...baseProgress, insightCount: 1, giftsSent: 2, maxHabitRun: 10 }),
    ).toEqual(['insight_seeker', 'echo_gifter', 'habit_hero'])
    expect(evaluateAchievements({ ...baseProgress, maxHabitRun: 9 })).toEqual([])
  })
})

describe('currentLoggingStreak', () => {
  const now = Date.UTC(2026, 0, 10, 15)
  const day = (offset: number) =>
    new Date(Date.UTC(2026, 0, 10 + offset, 12)).toISOString()

  test('returns 0 with no logs', () => {
    expect(currentLoggingStreak([], now)).toBe(0)
  })

  test('counts consecutive days ending today', () => {
    expect(currentLoggingStreak([day(0), day(-1), day(-2)], now)).toBe(3)
  })

  test('still alive when the last log was yesterday', () => {
    expect(currentLoggingStreak([day(-1), day(-2)], now)).toBe(2)
  })

  test('broken when the last log is older than yesterday', () => {
    expect(currentLoggingStreak([day(-2), day(-3)], now)).toBe(0)
  })

  test('a gap ends the count', () => {
    expect(currentLoggingStreak([day(0), day(-1), day(-3)], now)).toBe(2)
  })

  test('duplicate logs on one day count once', () => {
    expect(currentLoggingStreak([day(0), day(0), day(-1)], now)).toBe(2)
  })

  test('ignores unparseable dates', () => {
    expect(currentLoggingStreak(['not-a-date', day(0)], now)).toBe(1)
  })
})

describe('maxConsecutiveHabitDays', () => {
  const day = (offset: number) =>
    new Date(Date.UTC(2026, 0, 1 + offset)).toISOString()

  test('returns 0 with no habit data', () => {
    expect(maxConsecutiveHabitDays([])).toBe(0)
    expect(maxConsecutiveHabitDays([{ date: day(0), habits: [] }])).toBe(0)
  })

  test('counts consecutive days for the same habit', () => {
    const rows = [0, 1, 2].map((offset) => ({ date: day(offset), habits: ['water'] }))
    expect(maxConsecutiveHabitDays(rows)).toBe(3)
  })

  test('a gap resets the run', () => {
    const rows = [0, 1, 3, 4, 5].map((offset) => ({ date: day(offset), habits: ['water'] }))
    expect(maxConsecutiveHabitDays(rows)).toBe(3)
  })

  test('runs are tracked per habit, not across habits', () => {
    const rows = [
      { date: day(0), habits: ['water'] },
      { date: day(1), habits: ['reading'] },
      { date: day(2), habits: ['water'] },
    ]
    expect(maxConsecutiveHabitDays(rows)).toBe(1)
  })

  test('duplicate logs on the same day count once', () => {
    const rows = [
      { date: day(0), habits: ['water'] },
      { date: day(0), habits: ['water'] },
      { date: day(1), habits: ['water'] },
    ]
    expect(maxConsecutiveHabitDays(rows)).toBe(2)
  })

  test('ignores unparseable dates', () => {
    expect(maxConsecutiveHabitDays([{ date: 'not-a-date', habits: ['water'] }])).toBe(0)
  })
})
