import { useCallback, useEffect, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import { useAuth } from '../../lib/auth-context'
import { useFocusTrap } from '../../hooks/use-focus-trap'
import { ACHIEVEMENTS } from './achievements'
import {
  ACHIEVEMENT_UNLOCKED_EVENT,
  useAchievementSync,
  type AchievementUnlockedDetail,
} from './use-achievements'

function ConfettiBlast() {
  return (
    <div className="confetti-wrap" aria-hidden="true" style={{ zIndex: 10000 }}>
      {Array.from({ length: 24 }).map((_, index) => (
        <span key={index} style={{ ['--piece-delay' as string]: `${index * 35}ms` }} />
      ))}
    </div>
  )
}

// Mounted once in AppShell: keeps achievement state in sync and shows a
// celebration modal each time an achievement is unlocked for the first time.
export function AchievementsWatcher() {
  const { user } = useAuth()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [queue, setQueue] = useState<AchievementUnlockedDetail[]>([])

  useAchievementSync()

  useEffect(() => {
    const onUnlocked = (event: Event) => {
      const detail = (event as CustomEvent<AchievementUnlockedDetail>).detail
      setQueue((prev) => [...prev, detail])
      void queryClient.invalidateQueries({ queryKey: ['achievements', user?.id] })
      void queryClient.invalidateQueries({ queryKey: ['wallet', user?.id] })
      void queryClient.invalidateQueries({ queryKey: ['wallet-history', user?.id] })
      void queryClient.invalidateQueries({ queryKey: ['dashboard-echo', user?.id] })
    }

    window.addEventListener(ACHIEVEMENT_UNLOCKED_EVENT, onUnlocked)
    return () => window.removeEventListener(ACHIEVEMENT_UNLOCKED_EVENT, onUnlocked)
  }, [queryClient, user?.id])

  const current = queue[0]
  const definition = current
    ? ACHIEVEMENTS.find((entry) => entry.id === current.id)
    : undefined

  const dismiss = useCallback(() => {
    setQueue((prev) => prev.slice(1))
  }, [])

  const cardRef = useRef<HTMLDivElement>(null)
  useFocusTrap(Boolean(current), dismiss, cardRef)

  if (!current || !definition) return null

  return (
    <>
      <ConfettiBlast />
      <div
        className="modal-overlay"
        role="dialog"
        aria-modal="true"
        aria-labelledby="achievement-unlocked-title"
        style={{ zIndex: 9999 }}
        onClick={dismiss}
      >
        <div
          ref={cardRef}
          className="modal-card"
          tabIndex={-1}
          style={{ textAlign: 'center', gap: '0.5rem' }}
          onClick={(event) => event.stopPropagation()}
        >
          <div
            aria-hidden="true"
            style={{
              width: '64px',
              height: '64px',
              margin: '0 auto',
              borderRadius: '50%',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontWeight: 700,
              fontSize: '1.75rem',
              color: '#fff',
              background: 'linear-gradient(135deg, #f5a623, #d34b32)',
            }}
          >
            {definition.icon}
          </div>
          <h2 id="achievement-unlocked-title" style={{ margin: 0 }}>
            {'\u{1F3C6} Achievement unlocked!'}
          </h2>
          <p style={{ margin: 0, fontWeight: 600 }}>{definition.name}</p>
          <p className="muted" style={{ margin: 0 }}>
            {definition.description}
          </p>
          {current.reward > 0 ? (
            <p style={{ margin: 0, fontWeight: 700, color: 'var(--brand)' }}>
              +{current.reward} ECHO
            </p>
          ) : null}
          <div className="modal-actions" style={{ justifyContent: 'center' }}>
            <button
              type="button"
              className="secondary"
              onClick={() => {
                dismiss()
                navigate('/achievements')
              }}
            >
              View achievements
            </button>
            <button type="button" onClick={dismiss}>
              Nice!
            </button>
          </div>
        </div>
      </div>
    </>
  )
}
