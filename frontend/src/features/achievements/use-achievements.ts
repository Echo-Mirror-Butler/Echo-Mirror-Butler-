import { useEffect, useRef } from 'react'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'
import {
  ACHIEVEMENTS,
  currentLoggingStreak,
  evaluateAchievements,
  maxConsecutiveHabitDays,
  type AchievementId,
  type AchievementProgress,
} from './achievements'

export const ACHIEVEMENT_UNLOCKED_EVENT = 'echomirror:achievement-unlocked'

export type AchievementUnlockedDetail = {
  id: AchievementId
  reward: number
}

type UnlockResult = {
  success?: boolean
  newly_unlocked?: boolean
  reward?: number
}

// Unlocks via the unlock_achievement RPC (which also credits the ECHO
// bonus server side) and broadcasts an event on first unlock so the
// celebration modal fires exactly once.
export async function unlockAchievement(id: AchievementId): Promise<boolean> {
  const { data, error } = await supabase.rpc('unlock_achievement', {
    p_achievement_id: id,
  })
  if (error) return false

  const result = data as UnlockResult | null
  if (!result?.success || !result.newly_unlocked) return false

  window.dispatchEvent(
    new CustomEvent<AchievementUnlockedDetail>(ACHIEVEMENT_UNLOCKED_EVENT, {
      detail: { id, reward: result.reward ?? 0 },
    }),
  )
  return true
}

export type UnlockedMap = Partial<Record<AchievementId, string>>

async function fetchUnlocked(userId: string): Promise<UnlockedMap> {
  const { data, error } = await supabase
    .from('user_achievements')
    .select('achievement_id, unlocked_at')
    .eq('user_id', userId)
  if (error) throw error

  const map: UnlockedMap = {}
  for (const row of (data ?? []) as { achievement_id: AchievementId; unlocked_at: string }[]) {
    map[row.achievement_id] = row.unlocked_at
  }
  return map
}

export function useUnlockedAchievements(userId: string | undefined) {
  return useQuery({
    queryKey: ['achievements', userId],
    queryFn: () => fetchUnlocked(userId!),
    enabled: Boolean(userId),
  })
}

async function fetchProgress(userId: string): Promise<AchievementProgress> {
  const [logsRes, insightsRes, giftsRes] = await Promise.all([
    supabase.from('log_entries').select('date, habits').eq('user_id', userId),
    supabase
      .from('ai_insights')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId),
    supabase
      .from('gift_transactions')
      .select('id', { count: 'exact', head: true })
      .eq('sender_user_id', userId),
  ])

  const logs = (logsRes.data ?? []) as { date: string; habits: string[] | null }[]

  return {
    logCount: logs.length,
    currentStreak: currentLoggingStreak(logs.map((log) => log.date)),
    insightCount: insightsRes.count ?? 0,
    giftsSent: giftsRes.count ?? 0,
    maxHabitRun: maxConsecutiveHabitDays(
      logs.map((log) => ({ date: log.date, habits: log.habits ?? [] })),
    ),
  }
}

// Re-checks progress after logs/actions (the log, insight, and gift
// mutations invalidate 'achievement-progress') and unlocks anything newly
// earned. Stops querying once every derivable achievement is unlocked.
export function useAchievementSync() {
  const { user } = useAuth()
  const syncingRef = useRef(false)

  const unlockedQuery = useUnlockedAchievements(user?.id)
  const unlocked = unlockedQuery.data

  const allDerivableUnlocked =
    unlocked !== undefined &&
    ACHIEVEMENTS.every(
      (entry) => entry.id === 'global_citizen' || entry.id in unlocked,
    )

  const progressQuery = useQuery({
    queryKey: ['achievement-progress', user?.id],
    queryFn: () => fetchProgress(user!.id),
    enabled: Boolean(user?.id) && unlocked !== undefined && !allDerivableUnlocked,
  })

  const progress = progressQuery.data

  useEffect(() => {
    if (!user?.id || !unlocked || !progress || syncingRef.current) return

    const missing = evaluateAchievements(progress).filter((id) => !(id in unlocked))
    if (missing.length === 0) return

    syncingRef.current = true
    void (async () => {
      for (const id of missing) {
        await unlockAchievement(id)
      }
      syncingRef.current = false
    })()
  }, [user?.id, unlocked, progress])
}
