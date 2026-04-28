import { X, Trash2 } from 'lucide-react'
import { formatDistanceToNow } from 'date-fns'
import { MoodPin } from '../../../lib/types'

interface MyPinsSidebarProps {
  isOpen: boolean
  onClose: () => void
  myPins: MoodPin[]
  onDelete: (id: string) => void
}

const EMOJI_MAP: Record<string, string> = {
  happy: '😊',
  neutral: '😐',
  sad: '😔',
}

export function MyPinsSidebar({ isOpen, onClose, myPins, onDelete }: MyPinsSidebarProps) {
  return (
    <>
      {/* Overlay for mobile (optional on desktop, but good for focus) */}
      {isOpen && (
        <div 
          className="fixed inset-0 bg-black/20 backdrop-blur-sm z-40 transition-opacity" 
          onClick={onClose}
        />
      )}

      {/* Sidebar Panel */}
      <div className={`gm-sidebar ${isOpen ? 'open' : ''}`}>
        <div className="flex items-center justify-between p-4 border-b border-[var(--line)]">
          <h2 className="text-lg font-bold font-fraunces m-0">My Pins</h2>
          <button 
            onClick={onClose}
            className="p-2 bg-transparent text-[var(--muted)] hover:bg-[var(--surface-soft)] rounded-full transition-colors"
          >
            <X size={20} />
          </button>
        </div>

        <div className="p-4 overflow-y-auto h-full pb-20">
          {myPins.length === 0 ? (
            <div className="text-center mt-10">
              <p className="text-[var(--muted)] text-sm">
                You have no active pins. Drop one on the map!
              </p>
            </div>
          ) : (
            <div className="flex flex-col gap-3">
              {myPins.map((pin) => (
                <div 
                  key={pin.id} 
                  className="flex items-center justify-between p-3 rounded-xl border border-[var(--line)] bg-[var(--surface)] hover:shadow-sm transition-shadow"
                >
                  <div className="flex items-center gap-3">
                    <span className="text-2xl">{EMOJI_MAP[pin.sentiment] || '📍'}</span>
                    <div className="flex flex-col">
                      <span className="text-sm font-semibold capitalize text-[var(--text)]">
                        {pin.sentiment}
                      </span>
                      <span className="text-xs text-[var(--muted)]">
                        {formatDistanceToNow(new Date(pin.created_at), { addSuffix: true })}
                      </span>
                    </div>
                  </div>
                  
                  <button
                    onClick={() => onDelete(pin.id)}
                    className="p-2 text-red-500 hover:bg-red-50 rounded-full transition-colors bg-transparent border-none outline-none"
                    aria-label="Delete pin"
                    title="Delete pin"
                  >
                    <Trash2 size={16} />
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </>
  )
}
