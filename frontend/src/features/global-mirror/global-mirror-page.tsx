/**
 * Global Mirror Page  (#260, #306)
 *
 * Sections:
 * 1. Live SVG world map with real-time mood pins from Supabase Realtime
 * 2. Drop-a-pin panel (sentiment selector + geolocation)
 * 3. Scrolling ticker with live mood events (updated via Supabase Realtime)
 * 4. "Live" indicator reflecting Realtime connection state
 *
 * Issue #306 additions:
 * - Subscribe to mood_logs INSERT events via Supabase Realtime
 * - Aggregate new entries by country/city and update ticker without full refetch
 * - Throttle map updates to max 1 per second to avoid UI jank
 * - Show pulsing "Live" indicator when Realtime connection is active
 * - Handle connection drops and automatic reconnection gracefully
 * - No memory leaks on unmount (subscriptions properly cleaned up)
 */
import { useCallback, useEffect, useRef, useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import type { RealtimeChannel, REALTIME_SUBSCRIBE_STATES } from '@supabase/supabase-js'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'
import { MoodPinCommentsPanel } from '../../components/mood-pin-comments-panel'

// ── Types ─────────────────────────────────────────────────────────────────────

type MoodPin = {
  id: string
  grid_lat: number
  grid_lon: number
  sentiment: string
  created_at: string
  comment?: string
}

type MoodLogEvent = {
  id: string
  country: string | null
  city: string | null
  mood: string
  created_at: string
}

type Sentiment = 'happy' | 'sad' | 'stressed' | 'calm' | 'anxious'

type LiveStatus = 'connecting' | 'connected' | 'disconnected'

const SENTIMENTS: { value: Sentiment; label: string; emoji: string; color: string }[] = [
  { value: 'happy',    label: 'Happy',    emoji: '😊', color: '#22c55e' },
  { value: 'sad',      label: 'Sad',      emoji: '😔', color: '#60a5fa' },
  { value: 'stressed', label: 'Stressed', emoji: '😤', color: '#f97316' },
  { value: 'calm',     label: 'Calm',     emoji: '😌', color: '#818cf8' },
  { value: 'anxious',  label: 'Anxious',  emoji: '😰', color: '#f43f5e' },
]

const SENTIMENT_COLOR: Record<string, string> = Object.fromEntries(
  SENTIMENTS.map((s) => [s.value, s.color]),
)

const MOOD_COLOR: Record<string, string> = {
  happy: '#22c55e',
  calm: '#818cf8',
  focused: '#1463ff',
  energised: '#e67a00',
  anxious: '#f43f5e',
  sad: '#60a5fa',
  stressed: '#f97316',
  hopeful: '#0a8a5b',
  reflective: '#8b5cf6',
  content: '#1463ff',
  motivated: '#0a8a5b',
}

// ── Coordinate helpers ─────────────────────────────────────────────────────────

function anonymize(coord: number): number {
  return Math.round(coord * 10) / 10
}

function toSvgCoord(lat: number, lon: number): { x: number; y: number } {
  const x = ((lon + 180) / 360) * 800
  const y = ((90 - lat) / 180) * 400
  return { x, y }
}

// ── Data ──────────────────────────────────────────────────────────────────────

async function fetchPins(): Promise<MoodPin[]> {
  const { data, error } = await supabase
    .from('mood_pins')
    .select('id, grid_lat, grid_lon, sentiment, created_at')
    .order('created_at', { ascending: false })
    .limit(500)
  if (error) throw error
  return (data ?? []) as MoodPin[]
}

async function fetchRecentMoodLogs(): Promise<MoodLogEvent[]> {
  const { data, error } = await supabase
    .from('mood_logs')
    .select('id, country, city, mood, created_at')
    .order('created_at', { ascending: false })
    .limit(30)
  if (error) return []
  return (data ?? []) as MoodLogEvent[]
}

async function insertPin(
  userId: string,
  lat: number,
  lon: number,
  sentiment: Sentiment,
): Promise<void> {
  const { error } = await supabase.from('mood_pins').insert({
    user_id: userId,
    grid_lat: anonymize(lat),
    grid_lon: anonymize(lon),
    sentiment,
  })
  if (error) throw error
}

// ── Sub-components ────────────────────────────────────────────────────────────

function LiveIndicator({ status }: { status: LiveStatus }) {
  const colors: Record<LiveStatus, string> = {
    connecting: '#f97316',
    connected: '#22c55e',
    disconnected: '#94a3b8',
  }
  const labels: Record<LiveStatus, string> = {
    connecting: 'Connecting…',
    connected: 'Live',
    disconnected: 'Reconnecting…',
  }

  return (
    <div
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: '0.4rem',
        padding: '0.25rem 0.65rem',
        borderRadius: '999px',
        background: colors[status] + '18',
        border: `1px solid ${colors[status]}44`,
        fontSize: '0.78rem',
        fontWeight: 600,
        color: colors[status],
      }}
      aria-live="polite"
      aria-label={`Realtime connection status: ${labels[status]}`}
    >
      <span
        style={{
          width: 8,
          height: 8,
          borderRadius: '50%',
          background: colors[status],
          display: 'inline-block',
          animation: status === 'connected' ? 'live-pulse 1.5s ease-in-out infinite' : 'none',
        }}
      />
      {labels[status]}
    </div>
  )
}

function PinPopover({
  pin,
  x,
  y,
  onClose,
}: {
  pin: MoodPin
  x: number
  y: number
  onClose: () => void
}) {
  const sentiment = SENTIMENTS.find((s) => s.value === pin.sentiment)

  return (
    <div
      style={{
        position: 'absolute',
        left: x,
        top: y,
        transform: 'translate(-50%, -110%)',
        background: 'var(--surface)',
        border: '1px solid var(--line)',
        borderRadius: '10px',
        padding: '0.75rem 1rem',
        boxShadow: 'var(--shadow)',
        zIndex: 10,
        width: '200px',
        fontSize: '0.82rem',
      }}
    >
      <button
        type="button"
        onClick={onClose}
        style={{ position: 'absolute', top: 6, right: 8, background: 'none', border: 'none', cursor: 'pointer', color: 'var(--muted)' }}
        aria-label="Close popover"
      >
        ✕
      </button>
      <p style={{ margin: '0 0 4px', fontWeight: 600, color: 'var(--text)' }}>
        {sentiment?.emoji} {sentiment?.label ?? pin.sentiment}
      </p>
      <p style={{ margin: 0, color: 'var(--muted)' }}>
        {pin.created_at.slice(0, 10)}
      </p>
    </div>
  )
}

function MoodTicker({ events }: { events: MoodLogEvent[] }) {
  if (!events.length) return null

  const doubled = [...events, ...events]

  return (
    <div
      style={{
        overflow: 'hidden',
        borderRadius: '8px',
        background: 'var(--surface-soft)',
        border: '1px solid var(--line)',
        padding: '0.5rem 0',
      }}
      aria-label="Live mood ticker"
    >
      <div
        style={{
          display: 'flex',
          gap: '2rem',
          animation: 'ticker-scroll 30s linear infinite',
          whiteSpace: 'nowrap',
        }}
      >
        {doubled.map((event, i) => {
          const color = MOOD_COLOR[event.mood.toLowerCase()] ?? 'var(--brand)'
          const location = [event.city, event.country].filter(Boolean).join(', ') || 'Somewhere'
          return (
            <span
              key={`${event.id}-${i}`}
              style={{ display: 'inline-flex', alignItems: 'center', gap: '0.4rem', fontSize: '0.82rem', color: 'var(--text)' }}
            >
              <span
                style={{ width: 8, height: 8, borderRadius: '50%', background: color, display: 'inline-block', flexShrink: 0 }}
              />
              <span style={{ color: 'var(--muted)' }}>{location}</span>
              {' — '}
              <strong style={{ color }}>{event.mood}</strong>
            </span>
          )
        })}
      </div>
    </div>
  )
}

// ── Page ──────────────────────────────────────────────────────────────────────

export function GlobalMirrorPage() {
  const { user } = useAuth()
  const qc = useQueryClient()
  const pinChannelRef = useRef<RealtimeChannel | null>(null)
  const logChannelRef = useRef<RealtimeChannel | null>(null)
  const throttleTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const pendingPinInvalidate = useRef(false)

  const [selectedPin, setSelectedPin] = useState<{ pin: MoodPin; svgX: number; svgY: number } | null>(null)
  const [commentsPanelPinId, setCommentsPanelPinId] = useState<string | null>(null)
  const [selectedSentiment, setSelectedSentiment] = useState<Sentiment>('happy')
  const [geoStatus, setGeoStatus] = useState<'idle' | 'pending' | 'denied' | 'done'>('idle')
  const [dropError, setDropError] = useState<string | null>(null)
  const [liveStatus, setLiveStatus] = useState<LiveStatus>('connecting')
  const [tickerEvents, setTickerEvents] = useState<MoodLogEvent[]>([])

  const pinsQuery = useQuery({
    queryKey: ['mood-pins'],
    queryFn: fetchPins,
    enabled: Boolean(user?.id),
  })

  // Load initial ticker events
  useEffect(() => {
    fetchRecentMoodLogs().then(setTickerEvents)
  }, [])

  // Throttled map invalidation — max 1 per second
  const scheduleMapInvalidate = useCallback(() => {
    if (throttleTimerRef.current) {
      pendingPinInvalidate.current = true
      return
    }
    void qc.invalidateQueries({ queryKey: ['mood-pins'] })
    throttleTimerRef.current = setTimeout(() => {
      throttleTimerRef.current = null
      if (pendingPinInvalidate.current) {
        pendingPinInvalidate.current = false
        void qc.invalidateQueries({ queryKey: ['mood-pins'] })
      }
    }, 1000)
  }, [qc])

  // Supabase Realtime — mood_pins (map updates)
  useEffect(() => {
    const channel = supabase
      .channel('global-mirror-pins')
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'mood_pins' },
        () => { scheduleMapInvalidate() },
      )
      .subscribe((status: `${REALTIME_SUBSCRIBE_STATES}`) => {
        if (status === 'SUBSCRIBED') setLiveStatus('connected')
        else if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') setLiveStatus('disconnected')
        else setLiveStatus('connecting')
      })

    pinChannelRef.current = channel

    return () => {
      if (throttleTimerRef.current) clearTimeout(throttleTimerRef.current)
      void supabase.removeChannel(channel)
    }
  }, [scheduleMapInvalidate])

  // Supabase Realtime — mood_logs (ticker updates)
  useEffect(() => {
    const channel = supabase
      .channel('global-mirror-logs')
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'mood_logs' },
        (payload) => {
          const newEvent = payload.new as MoodLogEvent
          setTickerEvents((prev) => [newEvent, ...prev].slice(0, 30))
        },
      )
      .subscribe()

    logChannelRef.current = channel

    return () => { void supabase.removeChannel(channel) }
  }, [])

  const handleDropPin = useCallback(() => {
    if (!user?.id) return
    setGeoStatus('pending')
    setDropError(null)

    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        try {
          await insertPin(user.id, pos.coords.latitude, pos.coords.longitude, selectedSentiment)
          setGeoStatus('done')
          scheduleMapInvalidate()
          setTimeout(() => setGeoStatus('idle'), 2000)
        } catch {
          setDropError('Failed to drop pin. Please try again.')
          setGeoStatus('idle')
        }
      },
      () => { setGeoStatus('denied') },
    )
  }, [user?.id, selectedSentiment, scheduleMapInvalidate])

  const pins = pinsQuery.data ?? []

  return (
    <div className="page-wrap animate-stagger" style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
      {/* Header with Live indicator */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', flexWrap: 'wrap' }}>
        <div>
          <h1 style={{ margin: 0 }}>Global Mirror</h1>
          <p className="muted" style={{ margin: '0.25rem 0 0' }}>Live mood pins shared anonymously by users worldwide.</p>
        </div>
        <LiveIndicator status={liveStatus} />
      </div>

      {/* Live Ticker */}
      {tickerEvents.length > 0 && (
        <section aria-label="Live mood events ticker">
          <MoodTicker events={tickerEvents} />
        </section>
      )}

      {/* Map */}
      <section className="card" style={{ overflow: 'hidden', position: 'relative' }}>
        <svg
          viewBox="0 0 800 400"
          style={{ width: '100%', background: 'var(--surface-soft)', borderRadius: '12px', display: 'block' }}
          aria-label="World mood map"
          role="img"
        >
          <rect x={0} y={0} width={800} height={400} fill="var(--surface-soft)" />
          <text x={400} y={200} textAnchor="middle" fill="var(--line)" fontSize={13}>
            (World map outline — replace with react-simple-maps SVG paths)
          </text>

          {/* Mood pins */}
          {pins.map((pin) => {
            const { x, y } = toSvgCoord(pin.grid_lat, pin.grid_lon)
            return (
              <circle
                key={pin.id}
                cx={x}
                cy={y}
                r={5}
                fill={SENTIMENT_COLOR[pin.sentiment] ?? 'var(--brand)'}
                opacity={0.8}
                style={{ cursor: 'pointer' }}
                role="button"
                aria-label={`Mood pin: ${pin.sentiment}`}
                tabIndex={0}
                onClick={() => {
                  setSelectedPin({ pin, svgX: x, svgY: y })
                  setCommentsPanelPinId(pin.id)
                }}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' || e.key === ' ') {
                    setSelectedPin({ pin, svgX: x, svgY: y })
                    setCommentsPanelPinId(pin.id)
                  }
                }}
              />
            )
          })}
        </svg>

        {/* Popover */}
        {selectedPin && (
          <PinPopover
            pin={selectedPin.pin}
            x={(selectedPin.svgX / 800) * 100 + '%' as unknown as number}
            y={(selectedPin.svgY / 400) * 100 + '%' as unknown as number}
            onClose={() => setSelectedPin(null)}
          />
        )}
      </section>

      {/* Drop pin */}
      <section className="card">
        <h2 style={{ marginTop: 0 }}>Drop your mood pin</h2>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem', marginBottom: '1rem' }}>
          {SENTIMENTS.map((s) => (
            <button
              key={s.value}
              type="button"
              onClick={() => setSelectedSentiment(s.value)}
              aria-pressed={selectedSentiment === s.value}
              style={{
                padding: '0.4rem 0.9rem',
                borderRadius: '999px',
                border: `2px solid ${selectedSentiment === s.value ? s.color : 'var(--line)'}`,
                background: selectedSentiment === s.value ? s.color + '22' : 'transparent',
                color: 'var(--text)',
                cursor: 'pointer',
                fontSize: '0.85rem',
                fontWeight: selectedSentiment === s.value ? 600 : 400,
              }}
            >
              {s.emoji} {s.label}
            </button>
          ))}
        </div>

        {geoStatus === 'denied' && (
          <p role="alert" style={{ color: 'var(--danger)', fontSize: '0.85rem', marginBottom: '0.5rem' }}>
            Geolocation permission denied. Please allow location access in your browser settings.
          </p>
        )}
        {dropError && (
          <p role="alert" style={{ color: 'var(--danger)', fontSize: '0.85rem', marginBottom: '0.5rem' }}>{dropError}</p>
        )}

        <button
          type="button"
          className="btn-primary"
          onClick={handleDropPin}
          disabled={geoStatus === 'pending' || geoStatus === 'done'}
          style={{ padding: '0.55rem 1.25rem', borderRadius: '10px', background: 'var(--brand)', color: '#fff', border: 'none', cursor: 'pointer', fontWeight: 600 }}
        >
          {geoStatus === 'pending' ? 'Getting location…' : geoStatus === 'done' ? '📍 Pinned!' : '📍 Drop pin'}
        </button>
      </section>

      {/* Comments Panel */}
      {commentsPanelPinId && (
        <MoodPinCommentsPanel
          pinId={commentsPanelPinId}
          onClose={() => {
            setCommentsPanelPinId(null)
            setSelectedPin(null)
          }}
        />
      )}

      {/* Ticker animation keyframes */}
      <style>{`
        @keyframes ticker-scroll {
          0%   { transform: translateX(0); }
          100% { transform: translateX(-50%); }
        }
        @keyframes live-pulse {
          0%, 100% { opacity: 1; transform: scale(1); }
          50%       { opacity: 0.4; transform: scale(1.3); }
        }
      `}</style>
    </div>
  )
}
