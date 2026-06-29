import { useEffect, useState } from 'react'
import { ACHIEVEMENTS } from './achievements'

interface AchievementModalProps {
  achievementId: string | null
  onClose: () => void
}

export function AchievementModal({ achievementId, onClose }: AchievementModalProps) {
  const [isVisible, setIsVisible] = useState(false)

  useEffect(() => {
    if (achievementId) {
      setIsVisible(true)
      const timer = setTimeout(() => {
        setIsVisible(false)
        setTimeout(onClose, 300)
      }, 4000)
      return () => clearTimeout(timer)
    }
  }, [achievementId, onClose])

  if (!achievementId) return null

  const achievement = ACHIEVEMENTS[achievementId]
  if (!achievement) return null

  return (
    <>
      {isVisible && (
        <div
          className="confetti-overlay"
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            pointerEvents: 'none',
            zIndex: 9999,
            overflow: 'hidden',
          }}
          aria-hidden="true"
        >
          {Array.from({ length: 50 }).map((_, i) => (
            <div
              key={i}
              className="confetti-piece"
              style={{
                position: 'absolute',
                width: '10px',
                height: '10px',
                backgroundColor: ['#ff0000', '#00ff00', '#0000ff', '#ffff00', '#ff00ff', '#00ffff'][i % 6],
                left: `${Math.random() * 100}%`,
                top: '-20px',
                animation: `confetti-fall ${2 + Math.random() * 2}s linear forwards`,
                animationDelay: `${Math.random() * 0.5}s`,
              }}
            />
          ))}
        </div>
      )}

      <div
        className="modal-backdrop"
        style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          backgroundColor: 'rgba(0, 0, 0, 0.7)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 10000,
          opacity: isVisible ? 1 : 0,
          transition: 'opacity 0.3s ease',
        }}
        onClick={onClose}
      >
        <div
          className="modal-content achievement-modal"
          style={{
            backgroundColor: 'var(--surface)',
            borderRadius: '12px',
            padding: '2rem',
            maxWidth: '400px',
            width: '90%',
            textAlign: 'center',
            transform: isVisible ? 'scale(1)' : 'scale(0.8)',
            transition: 'transform 0.3s ease',
            border: '3px solid var(--brand)',
          }}
          onClick={(e) => e.stopPropagation()}
        >
          <div
            style={{
              fontSize: '4rem',
              marginBottom: '1rem',
              animation: 'bounce 1s ease infinite',
            }}
          >
            🏆
          </div>
          <h2 style={{ margin: '0.5rem 0', color: 'var(--brand)' }}>
            Achievement Unlocked!
          </h2>
          <div
            style={{
              fontSize: '3rem',
              margin: '1rem 0',
            }}
          >
            {achievement.icon}
          </div>
          <h3 style={{ margin: '0.5rem 0' }}>{achievement.name}</h3>
          <p className="muted" style={{ margin: '0.5rem 0' }}>
            {achievement.description}
          </p>
          {achievement.echoReward > 0 && (
            <p
              style={{
                fontSize: '1.25rem',
                fontWeight: 700,
                color: 'var(--success)',
                margin: '1rem 0',
              }}
            >
              +{achievement.echoReward} ECHO
            </p>
          )}
          <button
            type="button"
            onClick={onClose}
            style={{
              marginTop: '1rem',
              padding: '0.75rem 1.5rem',
              backgroundColor: 'var(--brand)',
              color: 'white',
              border: 'none',
              borderRadius: '6px',
              fontSize: '1rem',
              cursor: 'pointer',
            }}
          >
            Awesome!
          </button>
        </div>
      </div>

      <style>{`
        @keyframes confetti-fall {
          0% {
            transform: translateY(0) rotate(0deg);
            opacity: 1;
          }
          100% {
            transform: translateY(100vh) rotate(720deg);
            opacity: 0;
          }
        }

        @keyframes bounce {
          0%, 100% {
            transform: translateY(0);
          }
          50% {
            transform: translateY(-10px);
          }
        }
      `}</style>
    </>
  )
}
