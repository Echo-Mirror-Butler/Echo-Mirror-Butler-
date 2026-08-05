import { useRef } from 'react'
import { useFocusTrap } from '../hooks/use-focus-trap'
import { getLatestChangelogEntry } from '../hooks/use-whats-new'

export type WhatsNewModalProps = {
  isOpen: boolean
  onClose: () => void
}

export function WhatsNewModal({ isOpen, onClose }: WhatsNewModalProps) {
  const contentRef = useRef<HTMLDivElement>(null)
  useFocusTrap(isOpen, onClose, contentRef)

  const entry = getLatestChangelogEntry()

  if (!isOpen || !entry) return null

  return (
    <div
      className="modal-overlay"
      role="dialog"
      aria-modal="true"
      aria-labelledby="whats-new-title"
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        backgroundColor: 'rgba(0, 0, 0, 0.5)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 9999,
        padding: '1rem',
      }}
      onClick={onClose}
    >
      <div
        ref={contentRef}
        className="modal-content card"
        tabIndex={-1}
        style={{ width: '100%', maxWidth: '440px' }}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="card-header" style={{ marginBottom: '0.75rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <h2 id="whats-new-title" style={{ margin: 0 }}>What's new in v{entry.version}</h2>
          <button type="button" className="icon-btn" onClick={onClose} aria-label="Close" style={{ fontSize: '1.2rem', padding: '0.25rem' }}>
            ✕
          </button>
        </div>

        <ul style={{ margin: '0 0 1rem', paddingLeft: '1.25rem' }}>
          {entry.items.map((item) => (
            <li key={item} style={{ marginBottom: '0.4rem' }}>{item}</li>
          ))}
        </ul>

        <div className="modal-actions" style={{ justifyContent: 'flex-end' }}>
          <button type="button" onClick={onClose}>
            Got it
          </button>
        </div>
      </div>
    </div>
  )
}
