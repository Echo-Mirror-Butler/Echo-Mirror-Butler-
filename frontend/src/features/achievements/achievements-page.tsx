import { useQuery } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'
import { ACHIEVEMENTS } from './achievements'
import { formatDate } from '../../lib/date'

interface UserAchievement {
  id: string
  user_id: string
  achievement_id: string
  unlocked_at: string
}

async function fetchUserAchievements(userId: string): Promise<UserAchievement[]> {
  const { data, error } = await supabase
    .from('user_achievements')
    .select('*')
    .eq('user_id', userId)
    .order('unlocked_at', { ascending: false })

  if (error) throw error
  return (data ?? []) as UserAchievement[]
}

export function AchievementsPage() {
  const { user } = useAuth()

  const achievementsQuery = useQuery({
    queryKey: ['user-achievements', user?.id],
    queryFn: () => fetchUserAchievements(user!.id),
    enabled: !!user?.id,
  })

  const unlockedAchievementIds = new Set(
    achievementsQuery.data?.map((a) => a.achievement_id) ?? []
  )

  const unlockedCount = unlockedAchievementIds.size
  const totalCount = Object.keys(ACHIEVEMENTS).length

  return (
    <section className="feature-grid">
      <article className="card full-width">
        <div className="card-header">
          <h2>Achievements</h2>
        </div>
        <div style={{ padding: '1rem' }}>
          <p className="muted">
            {unlockedCount} of {totalCount} achievements unlocked
          </p>
        </div>
      </article>

      {Object.values(ACHIEVEMENTS).map((achievement) => {
        const isUnlocked = unlockedAchievementIds.has(achievement.id)
        const userAchievement = achievementsQuery.data?.find(
          (a) => a.achievement_id === achievement.id
        )

        return (
          <article
            key={achievement.id}
            className="card"
            style={{
              opacity: isUnlocked ? 1 : 0.6,
              border: isUnlocked ? '2px solid var(--brand)' : undefined,
            }}
          >
            <div style={{ padding: '1.5rem', textAlign: 'center' }}>
              <div
                style={{
                  fontSize: '3rem',
                  marginBottom: '0.75rem',
                  filter: isUnlocked ? 'none' : 'grayscale(100%)',
                }}
              >
                {isUnlocked ? achievement.icon : '🔒'}
              </div>
              <h3 style={{ margin: '0.5rem 0' }}>{achievement.name}</h3>
              <p className="muted" style={{ fontSize: '0.9rem', margin: '0.5rem 0' }}>
                {achievement.description}
              </p>
              {achievement.echoReward > 0 && (
                <p
                  style={{
                    fontSize: '0.85rem',
                    fontWeight: 600,
                    color: 'var(--brand)',
                    margin: '0.5rem 0',
                  }}
                >
                  +{achievement.echoReward} ECHO
                </p>
              )}
              {isUnlocked && userAchievement ? (
                <p className="muted" style={{ fontSize: '0.8rem', marginTop: '0.75rem' }}>
                  Unlocked {formatDate(userAchievement.unlocked_at)}
                </p>
              ) : (
                <p className="muted" style={{ fontSize: '0.8rem', marginTop: '0.75rem' }}>
                  {achievement.hint}
                </p>
              )}
            </div>
          </article>
        )
      })}
    </section>
  )
}
