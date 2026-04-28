import { useState } from 'react'
import { Plus, Map as MapIcon, Layers } from 'lucide-react'
import { useAuth } from '../../lib/auth-context'
import { useMoodPins } from './use-mood-pins'
import { MapContainer } from './components/MapContainer'
import { MoodModal } from './components/MoodModal'
import { MyPinsSidebar } from './components/MyPinsSidebar'

export function GlobalMirrorPage() {
  const { user } = useAuth()
  const { pins, myPins, loading, error, geoStatus, insertPin, deletePin } = useMoodPins()

  const [isModalOpen, setIsModalOpen] = useState(false)
  const [isSidebarOpen, setIsSidebarOpen] = useState(false)

  return (
    <div className="flex flex-col h-full w-full relative animate-stagger" style={{ minHeight: 'calc(100vh - 80px)' }}>
      {/* Header Area */}
      <div className="flex justify-between items-end mb-4 z-10 px-4 mt-2">
        <div>
          <h1 className="text-2xl md:text-3xl font-bold font-fraunces m-0 mb-1 flex items-center gap-2">
            <MapIcon size={24} className="text-[var(--brand)]" />
            Global Mirror
          </h1>
          <p className="text-[var(--muted)] m-0 text-sm md:text-base">
            Live mood pins shared anonymously worldwide.
          </p>
        </div>

        <div className="flex items-center gap-2">
          {/* Active pins badge */}
          <div className="hidden md:flex items-center gap-1.5 px-3 py-1.5 bg-[var(--surface)] border border-[var(--line)] rounded-full text-sm font-medium text-[var(--brand)] shadow-sm">
            <span className="relative flex h-2 w-2">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-[var(--brand)] opacity-75"></span>
              <span className="relative inline-flex rounded-full h-2 w-2 bg-[var(--brand)]"></span>
            </span>
            {pins.length} active
          </div>

          <button
            onClick={() => setIsSidebarOpen(true)}
            className="flex items-center gap-2 px-3 py-2 bg-[var(--surface)] hover:bg-[var(--surface-soft)] border border-[var(--line)] rounded-lg text-[var(--text)] transition-colors shadow-sm"
          >
            <Layers size={18} />
            <span className="hidden sm:inline font-medium">My Pins</span>
            {myPins.length > 0 && (
              <span className="bg-[var(--brand)] text-white text-xs font-bold px-1.5 py-0.5 rounded-full min-w-[20px] text-center">
                {myPins.length}
              </span>
            )}
          </button>
        </div>
      </div>

      {/* Main Map Container */}
      <div className="flex-1 w-full relative rounded-xl border border-[var(--line)] bg-[var(--surface-soft)] overflow-hidden shadow-sm flex items-center justify-center min-h-[400px]">
        {loading && pins.length === 0 ? (
          <div className="flex flex-col items-center text-[var(--muted)] animate-pulse">
            <MapIcon size={48} className="mb-4 opacity-50" />
            <p>Loading map data...</p>
          </div>
        ) : (
          <MapContainer pins={pins} />
        )}
      </div>

      {/* Floating Action Button (FAB) */}
      <button
        onClick={() => setIsModalOpen(true)}
        className="gm-fab group"
        aria-label="Drop a pin"
        disabled={!user}
      >
        <Plus size={28} className="transition-transform group-hover:rotate-90" />
      </button>

      {/* Sub-components */}
      <MoodModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        onPost={insertPin}
        geoStatus={geoStatus}
        error={error}
      />

      <MyPinsSidebar
        isOpen={isSidebarOpen}
        onClose={() => setIsSidebarOpen(false)}
        myPins={myPins}
        onDelete={deletePin}
      />
    </div>
  )
}
