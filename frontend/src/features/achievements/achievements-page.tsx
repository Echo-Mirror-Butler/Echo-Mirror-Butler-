import { useAuth } from '../../lib/auth-context'
import { formatDate } from '../../lib/date'
import { ACHIEVEMENTS, type AchievementDef } from './achievements'
import { useUnlockedAchievements } from './use-achievements'

function LockIcon() {
  return (
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <rect x="4" y="11" width="16" height="10" rx="2" />
      <path d="M8 11V7a4 4 0 0 1 8 0v4" />
    </svg>
  )
}

function BadgeCard({
  definition,
  unlockedAt,
}: {
  definition: AchievementDef
  unlockedAt: string | undefined
}) {
  const isUnlocked = Boolean(unlockedAt)

  return (
    <div
      className="card"
      role="listitem"
      aria-label={`${definition.name}: ${isUnlocked ? 'unlocked' : 'locked'}`}
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        textAlign: 'center',
        gap: '0.6rem',
        opacity: isUnlocked ? 1 : 0.6,
      }}
    >
      <div
        aria-hidden="true"
        style={{
          width: '56px',
          height: '56px',
          borderRadius: '50%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontWeight: 700,
          fontSize: '1.5rem',
          color: '#fff',
          background: isUnlocked
            ? 'linear-gradient(135deg, #f5a623, #d34b32)'
            : 'var(--muted)',
          filter: isUnlocked ? 'none' : 'grayscale(1)',
        }}
      >
        {isUnlocked ? definition.icon : <LockIcon />}
      </div>

      <div>
        <h3 style={{ margin: 0, fontSize: '1rem' }}>{definition.name}</h3>
        <p className="muted" style={{ margin: '0.25rem 0 0', fontSize: '0.85rem' }}>
          {definition.description}
        </p>
      </div>

      {definition.echoReward > 0 ? (
        <span style={{ fontWeight: 600, fontSize: '0.85rem', color: 'var(--brand)' }}>
          +{definition.echoReward} ECHO
        </span>
      ) : null}

      {isUnlocked ? (
        <span className="muted" style={{ fontSize: '0.8rem' }}>
          Unlocked {formatDate(unlockedAt!)}
        </span>
      ) : (
        <span className="muted" style={{ fontSize: '0.8rem', fontStyle: 'italic' }}>
          {definition.hint}
        </span>
      )}
    </div>
  )
}

export function AchievementsPage() {
  const { user } = useAuth()
  const unlockedQuery = useUnlockedAchievements(user?.id)

  if (unlockedQuery.isLoading) {
    return <div className="page-message">Loading achievements...</div>
  }

  if (unlockedQuery.isError) {
    return (
      <div className="page-wrap">
        <p className="muted">Failed to load achievements.</p>
        <button type="button" onClick={() => void unlockedQuery.refetch()}>
          Retry
        </button>
      </div>
    )
  }

  const unlocked = unlockedQuery.data ?? {}
  const unlockedCount = ACHIEVEMENTS.filter((entry) => entry.id in unlocked).length

  return (
    <div className="page-wrap" style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
      <div>
        <h1 style={{ margin: 0 }}>Achievements</h1>
        <p className="muted" style={{ margin: '0.25rem 0 0' }}>
          {unlockedCount} of {ACHIEVEMENTS.length} unlocked. Milestone badges earn bonus ECHO.
        </p>
      </div>

      <div
        role="list"
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))',
          gap: '1rem',
        }}
      >
        {ACHIEVEMENTS.map((definition) => (
          <BadgeCard
            key={definition.id}
            definition={definition}
            unlockedAt={unlocked[definition.id]}
          />
        ))}
      </div>
    </div>
  )
}
