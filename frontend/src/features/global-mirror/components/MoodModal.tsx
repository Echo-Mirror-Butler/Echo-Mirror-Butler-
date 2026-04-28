import { useState, useEffect } from 'react'
import { X, MapPin } from 'lucide-react'
import { Sentiment } from '../../../lib/types'

interface MoodModalProps {
  isOpen: boolean
  onClose: () => void
  onPost: (sentiment: Sentiment) => Promise<void>
  geoStatus: 'idle' | 'pending' | 'denied' | 'done'
  error: string | null
}

const SENTIMENTS: { value: Sentiment; label: string; emoji: string; color: string }[] = [
  { value: 'happy', label: 'Happy', emoji: '😊', color: '#22c55e' },
  { value: 'neutral', label: 'Neutral', emoji: '😐', color: '#f59e0b' },
  { value: 'sad', label: 'Sad', emoji: '😔', color: '#3b82f6' },
]

export function MoodModal({ isOpen, onClose, onPost, geoStatus, error }: MoodModalProps) {
  const [selected, setSelected] = useState<Sentiment>('happy')

  useEffect(() => {
    const handleEsc = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', handleEsc)
    return () => window.removeEventListener('keydown', handleEsc)
  }, [onClose])

  if (!isOpen) return null

  const handlePost = async () => {
    try {
      await onPost(selected)
      // Note: Modal will remain open while geoStatus is pending, 
      // then close via the parent after success if desired, 
      // but usually users want to see the "done" state briefly.
      // We'll let the parent component close it.
    } catch (err) {
      // Error handled by hook and passed down
    }
  }

  return (
    <>
      <div className="gm-modal-backdrop" onClick={onClose} />
      <div className="gm-modal">
        <div className="flex justify-between items-center mb-4">
          <h2 className="text-xl font-bold m-0 font-fraunces">Drop your mood pin</h2>
          <button
            onClick={onClose}
            className="p-1 bg-transparent hover:bg-gray-100 rounded-full transition-colors text-gray-500"
            aria-label="Close"
          >
            <X size={20} />
          </button>
        </div>

        <p className="text-sm text-[var(--muted)] mb-5">
          Share how you're feeling. Your location will be generalized to protect privacy.
        </p>

        <div className="flex gap-2 mb-6 justify-center">
          {SENTIMENTS.map((s) => (
            <button
              key={s.value}
              onClick={() => setSelected(s.value)}
              className="gm-sentiment-chip"
              style={{
                borderColor: selected === s.value ? s.color : 'var(--line)',
                backgroundColor: selected === s.value ? `${s.color}22` : 'transparent',
                fontWeight: selected === s.value ? 600 : 400,
              }}
            >
              <span className="text-xl mr-2">{s.emoji}</span>
              {s.label}
            </button>
          ))}
        </div>

        {geoStatus === 'denied' && (
          <p className="text-[var(--danger)] text-sm mb-3">
            Location access denied. Please enable it in your browser.
          </p>
        )}
        
        {error && (
          <p className="text-[var(--danger)] text-sm mb-3">
            {error}
          </p>
        )}

        <button
          onClick={handlePost}
          disabled={geoStatus === 'pending' || geoStatus === 'done'}
          className="w-full flex items-center justify-center gap-2 py-3 rounded-xl bg-[var(--brand)] text-white font-semibold transition-all hover:bg-[var(--brand-strong)] disabled:opacity-60"
        >
          {geoStatus === 'pending' ? (
            'Getting location...'
          ) : geoStatus === 'done' ? (
            '📍 Pinned!'
          ) : (
            <>
              <MapPin size={18} />
              Post Pin
            </>
          )}
        </button>
      </div>
    </>
  )
}
