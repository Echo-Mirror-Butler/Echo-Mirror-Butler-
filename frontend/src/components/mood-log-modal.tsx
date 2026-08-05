import { useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { LogEntryForm } from '../features/logs/components/log-entry-form'
import { useFocusTrap } from '../hooks/use-focus-trap'

export type MoodLogModalProps = {
  isOpen: boolean
  onClose: () => void
}

export function MoodLogModal({ isOpen, onClose }: MoodLogModalProps) {
  const navigate = useNavigate()
  const contentRef = useRef<HTMLDivElement>(null)

  // Trap focus while open, close on Escape, restore focus to trigger on close
  useFocusTrap(isOpen, onClose, contentRef)

  if (!isOpen) return null

  return (
    <div
      className="modal-overlay"
      role="dialog"
      aria-modal="true"
      aria-labelledby="mood-log-modal-title"
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
        zIndex: 9999, // ensures it sits above everything
        padding: '1rem',
        backdropFilter: 'blur(2px)' // clean modern look
      }}
      onClick={onClose}
    >
      <div
        ref={contentRef}
        className="modal-content card"
        tabIndex={-1}
        style={{ width: '100%', maxWidth: '500px', maxHeight: '90vh', overflowY: 'auto' }}
        onClick={(e) => e.stopPropagation()} // Prevent clicking inside from closing modal
      >
        <div className="card-header" style={{ marginBottom: '1rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <h2 id="mood-log-modal-title" style={{ margin: 0 }}>Log Mood</h2>
          <button type="button" className="icon-btn" onClick={onClose} aria-label="Close modal" style={{ fontSize: '1.2rem', padding: '0.25rem' }}>
            ✕
          </button>
        </div>
        
        <LogEntryForm
          mode="create"
          onSuccess={onClose}
          onCancel={onClose}
          onExistingFound={(existingId) => {
            // If they already logged today, close modal and go to edit page
            onClose()
            navigate(`/logs/${existingId}/edit`)
          }}
        />
      </div>
    </div>
  )
}
