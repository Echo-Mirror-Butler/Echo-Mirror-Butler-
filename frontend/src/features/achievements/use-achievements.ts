import { useEffect, useState } from 'react'
import { useQuery, useQueryClient, useMutation } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'
import { ACHIEVEMENTS } from './achievements'

interface UserAchievement {
  id: string
  user_id: string
  achievement_id: string
  unlocked_at: string
}

async function fetchUserAchievements(userId: string): Promise<Set<string>> {
  const { data, error } = await supabase
    .from('user_achievements')
    .select('achievement_id')
    .eq('user_id', userId)

  if (error) throw error
  return new Set((data ?? []).map((a) => a.achievement_id))
}

async function unlockAchievement(userId: string, achievementId: string): Promise<void> {
  const { error } = await supabase
    .from('user_achievements')
    .insert({
      user_id: userId,
      achievement_id: achievementId,
    })

  if (error) throw error
}

async function awardEchoReward(userId: string, amount: number, reason: string): Promise<void> {
  const { error } = await supabase
    .from('echo_rewards')
    .insert({
      user_id: userId,
      amount,
      reason,
    })

  if (error) throw error

  // Update wallet balance
  const { error: balanceError } = await supabase.rpc('add_echo_to_wallet', {
    p_user_id: userId,
    p_amount: amount,
  })

  if (balanceError) {
    console.error('Failed to update wallet balance:', balanceError)
  }
}

export function useAchievements() {
  const { user } = useAuth()
  const queryClient = useQueryClient()
  const [newlyUnlocked, setNewlyUnlocked] = useState<string | null>(null)

  const achievementsQuery = useQuery({
    queryKey: ['user-achievements', user?.id],
    queryFn: () => fetchUserAchievements(user!.id),
    enabled: !!user?.id,
  })

  const unlockMutation = useMutation({
    mutationFn: ({ achievementId }: { achievementId: string }) =>
      unlockAchievement(user!.id, achievementId),
    onSuccess: async (_, { achievementId }) => {
      setNewlyUnlocked(achievementId)
      await queryClient.invalidateQueries({ queryKey: ['user-achievements', user?.id] })
      await queryClient.invalidateQueries({ queryKey: ['wallet', user?.id] })
    },
  })

  const checkAndUnlockAchievement = async (
    achievementId: string,
    condition: () => boolean | Promise<boolean>
  ) => {
    if (!user || achievementsQuery.isLoading) return

    const unlockedIds = achievementsQuery.data ?? new Set()
    if (unlockedIds.has(achievementId)) return

    const isMet = await condition()
    if (isMet) {
      await unlockMutation.mutateAsync({ achievementId: achievementId })

      // Award ECHO if applicable
      const achievement = ACHIEVEMENTS[achievementId]
      if (achievement && achievement.echoReward > 0) {
        await awardEchoReward(user.id, achievement.echoReward, `achievement_${achievementId}`)
      }
    }
  }

  const dismissModal = () => {
    setNewlyUnlocked(null)
  }

  return {
    unlockedIds: achievementsQuery.data ?? new Set(),
    newlyUnlocked,
    checkAndUnlockAchievement,
    dismissModal,
    isLoading: achievementsQuery.isLoading,
  }
}
