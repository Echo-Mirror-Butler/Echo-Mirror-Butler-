export interface Achievement {
  id: string
  name: string
  description: string
  icon: string
  echoReward: number
  hint: string
}

export const ACHIEVEMENTS: Record<string, Achievement> = {
  first_log: {
    id: 'first_log',
    name: 'First Log',
    description: 'Log your first mood entry',
    icon: '📝',
    echoReward: 0,
    hint: 'Log your mood to unlock this achievement',
  },
  week_warrior: {
    id: 'week_warrior',
    name: 'Week Warrior',
    description: '7-day logging streak',
    icon: '🔥',
    echoReward: 10,
    hint: 'Log your mood for 7 consecutive days',
  },
  month_master: {
    id: 'month_master',
    name: 'Month Master',
    description: '30-day logging streak',
    icon: '🏆',
    echoReward: 50,
    hint: 'Log your mood for 30 consecutive days',
  },
  century: {
    id: 'century',
    name: 'Century',
    description: '100-day logging streak',
    icon: '💎',
    echoReward: 200,
    hint: 'Log your mood for 100 consecutive days',
  },
  insight_seeker: {
    id: 'insight_seeker',
    name: 'Insight Seeker',
    description: 'Generate your first AI insight',
    icon: '✨',
    echoReward: 0,
    hint: 'Generate an AI insight to unlock this achievement',
  },
  echo_gifter: {
    id: 'echo_gifter',
    name: 'ECHO Gifter',
    description: 'Send ECHO to another user',
    icon: '🎁',
    echoReward: 0,
    hint: 'Send ECHO to another user to unlock this achievement',
  },
  habit_hero: {
    id: 'habit_hero',
    name: 'Habit Hero',
    description: 'Log the same habit 10 days in a row',
    icon: '⭐',
    echoReward: 0,
    hint: 'Log the same habit for 10 consecutive days',
  },
  global_citizen: {
    id: 'global_citizen',
    name: 'Global Citizen',
    description: 'Drop a pin on the Global Mirror',
    icon: '🌍',
    echoReward: 0,
    hint: 'Drop a pin on the Global Mirror to unlock this achievement',
  },
}

export const ACHIEVEMENT_LIST = Object.values(ACHIEVEMENTS)
