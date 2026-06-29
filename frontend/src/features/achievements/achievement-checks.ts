import { supabase } from '../../lib/supabase'

export async function checkFirstLog(userId: string): Promise<boolean> {
  const { count, error } = await supabase
    .from('log_entries')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId)

  if (error) return false
  return (count ?? 0) >= 1
}

export async function checkWeekWarrior(userId: string): Promise<boolean> {
  const { data, error } = await supabase.rpc('get_current_streak', {
    user_id: userId,
  })

  if (error) return false
  return Number(data ?? 0) >= 7
}

export async function checkMonthMaster(userId: string): Promise<boolean> {
  const { data, error } = await supabase.rpc('get_current_streak', {
    user_id: userId,
  })

  if (error) return false
  return Number(data ?? 0) >= 30
}

export async function checkCentury(userId: string): Promise<boolean> {
  const { data, error } = await supabase.rpc('get_current_streak', {
    user_id: userId,
  })

  if (error) return false
  return Number(data ?? 0) >= 100
}

export async function checkInsightSeeker(userId: string): Promise<boolean> {
  const { count, error } = await supabase
    .from('ai_insights')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId)

  if (error) return false
  return (count ?? 0) >= 1
}

export async function checkEchoGifter(userId: string): Promise<boolean> {
  const { count, error } = await supabase
    .from('gift_transactions')
    .select('id', { count: 'exact', head: true })
    .eq('sender_id', userId)

  if (error) return false
  return (count ?? 0) >= 1
}

export async function checkHabitHero(userId: string): Promise<boolean> {
  // Check if user has logged the same habit for 10 consecutive days
  const { data, error } = await supabase
    .from('log_entries')
    .select('habits, date')
    .eq('user_id', userId)
    .order('date', { ascending: false })
    .limit(10)

  if (error || !data) return false

  // Get all habits from the last 10 entries
  const habits = data.flatMap((entry: any) => entry.habits || [])

  // Check if any habit appears at least 10 times
  const habitCounts = habits.reduce((acc: Record<string, number>, habit: string) => {
    acc[habit] = (acc[habit] || 0) + 1
    return acc
  }, {} as Record<string, number>)

  return Object.values(habitCounts).some((count: unknown) => (count as number) >= 10)
}

export async function checkGlobalCitizen(userId: string): Promise<boolean> {
  const { count, error } = await supabase
    .from('global_mirror_pins')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId)

  if (error) return false
  return (count ?? 0) >= 1
}

export const achievementCheckers = {
  first_log: checkFirstLog,
  week_warrior: checkWeekWarrior,
  month_master: checkMonthMaster,
  century: checkCentury,
  insight_seeker: checkInsightSeeker,
  echo_gifter: checkEchoGifter,
  habit_hero: checkHabitHero,
  global_citizen: checkGlobalCitizen,
}
