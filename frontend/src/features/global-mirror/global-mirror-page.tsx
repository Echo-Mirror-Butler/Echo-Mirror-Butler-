/**
 * Global Mirror Page  (#260, #306, #434)
 *
 * #434 additions:
 * - Replace placeholder SVG with react-simple-maps ComposableMap + Geographies
 * - Mood pins rendered as <Marker> at correct lat/lon positions
 * - Pulsing animation for newly inserted pins (Realtime INSERT events)
 * - Simple grid-bucket clustering when zoom is low
 * - ZoomableGroup for zoom + pan (desktop scroll, mobile pinch/touch)
 * - "Drop a pin" uses browser geolocation (already wired)
 * - Light/dark mode via CSS variables (--bg-page for ocean, --bg-card for land)
 * - lp-ring concentric animation as loading skeleton while geo data loads
 * - Fallback static SVG if react-simple-maps fails to load
 * - Responsive: fills container width, maintains 16:9 aspect ratio
 * - Mobile touch gestures supported by ZoomableGroup natively
 */
import {
  useCallback,
  useEffect,
  useRef,
  useState,
  useMemo,
} from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import type { RealtimeChannel, REALTIME_SUBSCRIBE_STATES } from '@supabase/supabase-js'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'
import { MoodPinCommentsPanel } from '../../components/mood-pin-comments-panel'
import { unlockAchievement } from '../achievements/use-achievements'

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

// ── Constants ─────────────────────────────────────────────────────────────────

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
  happy: '#22c55e', calm: '#818cf8', focused: '#1463ff', energised: '#e67a00',
  anxious: '#f43f5e', sad: '#60a5fa', stressed: '#f97316', hopeful: '#0a8a5b',
  reflective: '#8b5cf6', content: '#1463ff', motivated: '#0a8a5b',
}

// Public CDN topojson (no build step required)
const WORLD_TOPO_URL =
  'https://cdn.jsdelivr.net/npm/world-atlas@2/countries-110m.json'

// ── Coordinate helpers ─────────────────────────────────────────────────────────

function anonymize(coord: number): number {
  return Math.round(coord * 10) / 10
}

// ── Grid-bucket clustering ─────────────────────────────────────────────────────
//
// Bucket pins into (lat/gridSize, lon/gridSize) cells.
// When zoom >= CLUSTER_ZOOM_THRESHOLD show individual pins;
// below that threshold show cluster circles sized by count.

const CLUSTER_ZOOM_THRESHOLD = 2
const CLUSTER_GRID = 15 // degrees per cell

type ClusterBucket = {
  key: string
  lat: number
  lon: number
  count: number
  dominantSentiment: string
  newestPinId: string
  pins: MoodPin[]
}

function clusterPins(pins: MoodPin[], zoom: number): ClusterBucket[] {
  if (zoom >= CLUSTER_ZOOM_THRESHOLD) {
    // No clustering — return each pin as its own singleton bucket
    return pins.map((pin) => ({
      key: pin.id,
      lat: pin.grid_lat,
      lon: pin.grid_lon,
      count: 1,
      dominantSentiment: pin.sentiment,
      newestPinId: pin.id,
      pins: [pin],
    }))
  }

  const buckets = new Map<string, MoodPin[]>()
  for (const pin of pins) {
    const bLat = Math.floor(pin.grid_lat / CLUSTER_GRID) * CLUSTER_GRID
    const bLon = Math.floor(pin.grid_lon / CLUSTER_GRID) * CLUSTER_GRID
    const key = `${bLat}:${bLon}`
    if (!buckets.has(key)) buckets.set(key, [])
    buckets.get(key)!.push(pin)
  }

  return Array.from(buckets.entries()).map(([key, group]) => {
    // centroid
    const lat = group.reduce((s, p) => s + p.grid_lat, 0) / group.length
    const lon = group.reduce((s, p) => s + p.grid_lon, 0) / group.length
    // dominant sentiment by frequency
    const freq: Record<string, number> = {}
    for (const p of group) freq[p.sentiment] = (freq[p.sentiment] ?? 0) + 1
    const dominantSentiment = Object.entries(freq).sort((a, b) => b[1] - a[1])[0][0]
    // newest pin for pulse animation
    const newestPinId = group.sort(
      (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
    )[0].id

    return { key, lat, lon, count: group.length, dominantSentiment, newestPinId, pins: group }
  })
}

// ── Data fetchers ─────────────────────────────────────────────────────────────

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

// ── Loading skeleton (lp-ring concentric animation) ──────────────────────────

function MapLoadingSkeleton() {
  return (
    <div
      className="map-skeleton"
      style={{
        width: '100%',
        aspectRatio: '16/9',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: 'var(--surface-soft)',
        borderRadius: '12px',
        position: 'relative',
        overflow: 'hidden',
      }}
      aria-label="Loading world map…"
      role="status"
    >
      {[80, 130, 180, 230].map((r) => (
        <div
          key={r}
          className="lp-ring"
          style={{
            position: 'absolute',
            width: r * 2,
            height: r * 2,
            borderRadius: '50%',
            border: '1.5px solid var(--brand)',
            opacity: 0.15,
            animation: `lp-ring-pulse 2.4s ease-in-out ${r / 200}s infinite`,
          }}
        />
      ))}
      <span style={{ color: 'var(--muted)', fontSize: '0.85rem', position: 'relative', zIndex: 1 }}>
        Loading map…
      </span>
    </div>
  )
}

// ── Static fallback map (shown if react-simple-maps fails) ───────────────────

function StaticFallbackMap({ pins }: { pins: MoodPin[] }) {
  return (
    <svg
      viewBox="0 0 800 400"
      style={{ width: '100%', background: 'var(--surface-soft)', borderRadius: '12px', display: 'block' }}
      aria-label="World mood map (static fallback)"
      role="img"
    >
      <rect x={0} y={0} width={800} height={400} fill="var(--surface-soft)" />
      <text x={400} y={195} textAnchor="middle" fill="var(--muted)" fontSize={12}>
        Map unavailable — showing pin positions only
      </text>
      {pins.map((pin) => {
        const x = ((pin.grid_lon + 180) / 360) * 800
        const y = ((90 - pin.grid_lat) / 180) * 400
        return (
          <circle
            key={pin.id}
            cx={x} cy={y} r={4}
            fill={SENTIMENT_COLOR[pin.sentiment] ?? 'var(--brand)'}
            opacity={0.75}
          />
        )
      })}
    </svg>
  )
}

// ── Interactive World Map ─────────────────────────────────────────────────────

type WorldMapProps = {
  pins: MoodPin[]
  newPinIds: Set<string>
  zoom: number
  onZoomChange: (z: number) => void
  onPinClick: (bucket: ClusterBucket) => void
}

function WorldMap({ pins, newPinIds, zoom, onZoomChange, onPinClick }: WorldMapProps) {
  const [mapError, setMapError] = useState(false)
  const [RSM, setRSM] = useState<{
    ComposableMap: React.ElementType
    Geographies: React.ElementType
    Geography: React.ElementType
    Marker: React.ElementType
    ZoomableGroup: React.ElementType
  } | null>(null)

  useEffect(() => {
    import('react-simple-maps')
      .then((mod) => {
        setRSM({
          ComposableMap: mod.ComposableMap,
          Geographies: mod.Geographies,
          Geography: mod.Geography,
          Marker: mod.Marker,
          ZoomableGroup: mod.ZoomableGroup,
        })
      })
      .catch(() => setMapError(true))
  }, [])

  const clusters = useMemo(() => clusterPins(pins, zoom), [pins, zoom])

  if (mapError) return <StaticFallbackMap pins={pins} />
  if (!RSM) return <MapLoadingSkeleton />

  const { ComposableMap, Geographies, Geography, Marker, ZoomableGroup } = RSM

  return (
    <div
      style={{ width: '100%', position: 'relative', lineHeight: 0 }}
      aria-label="Interactive world mood map"
    >
      {/* Zoom controls */}
      <div
        style={{
          position: 'absolute',
          top: 12,
          right: 12,
          zIndex: 5,
          display: 'flex',
          flexDirection: 'column',
          gap: 4,
        }}
      >
        {[
          { label: '+', delta: 0.5 },
          { label: '−', delta: -0.5 },
        ].map(({ label, delta }) => (
          <button
            key={label}
            type="button"
            aria-label={delta > 0 ? 'Zoom in' : 'Zoom out'}
            onClick={() => onZoomChange(Math.min(8, Math.max(1, zoom + delta)))}
            style={{
              width: 32, height: 32, borderRadius: 8,
              border: '1px solid var(--line)',
              background: 'var(--surface)',
              color: 'var(--text)',
              fontSize: '1.1rem',
              cursor: 'pointer',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}
          >
            {label}
          </button>
        ))}
        <button
          type="button"
          aria-label="Reset zoom"
          onClick={() => onZoomChange(1)}
          style={{
            width: 32, height: 32, borderRadius: 8,
            border: '1px solid var(--line)',
            background: 'var(--surface)',
            color: 'var(--muted)',
            fontSize: '0.65rem',
            cursor: 'pointer',
          }}
        >
          ↺
        </button>
      </div>

      <ComposableMap
        projectionConfig={{ scale: 147 }}
        style={{ width: '100%', height: 'auto' }}
      >
        <ZoomableGroup
          zoom={zoom}
          onMoveEnd={({ zoom: z }: { zoom: number }) => onZoomChange(z)}
        >
          <Geographies geography={WORLD_TOPO_URL}>
            {({ geographies }: { geographies: unknown[] }) =>
              geographies.map((geo: unknown) => {
                const g = geo as { rsmKey: string }
                return (
                  <Geography
                    key={g.rsmKey}
                    geography={geo}
                    style={{
                      default: {
                        fill: 'var(--bg-card, #e8edf5)',
                        stroke: 'var(--line, #c8d4e8)',
                        strokeWidth: 0.4,
                        outline: 'none',
                      },
                      hover: {
                        fill: 'var(--surface, #dde6f2)',
                        stroke: 'var(--line, #c8d4e8)',
                        strokeWidth: 0.4,
                        outline: 'none',
                      },
                      pressed: { outline: 'none' },
                    }}
                  />
                )
              })
            }
          </Geographies>

          {/* Mood pin clusters / individual pins */}
          {clusters.map((bucket) => {
            const color = SENTIMENT_COLOR[bucket.dominantSentiment] ?? 'var(--brand)'
            const isNew = bucket.pins.some((p) => newPinIds.has(p.id))
            const r = bucket.count === 1 ? 4 : Math.min(12, 5 + Math.log2(bucket.count) * 2)

            return (
              <Marker
                key={bucket.key}
                coordinates={[bucket.lon, bucket.lat] as [number, number]}
              >
                {/* Pulse ring for new pins */}
                {isNew && (
                  <circle
                    r={r + 5}
                    fill="none"
                    stroke={color}
                    strokeWidth={1.5}
                    opacity={0.5}
                    style={{ animation: 'pin-pulse 1.2s ease-out forwards' }}
                  />
                )}
                <circle
                  r={r}
                  fill={color}
                  fillOpacity={0.82}
                  stroke="rgba(255,255,255,0.6)"
                  strokeWidth={0.8}
                  style={{ cursor: 'pointer', transition: 'r 0.2s ease' }}
                  role="button"
                  tabIndex={0}
                  aria-label={
                    bucket.count === 1
                      ? `Mood pin: ${bucket.dominantSentiment}`
                      : `${bucket.count} pins — mostly ${bucket.dominantSentiment}`
                  }
                  onClick={() => onPinClick(bucket)}
                  onKeyDown={(e: React.KeyboardEvent) => {
                    if (e.key === 'Enter' || e.key === ' ') onPinClick(bucket)
                  }}
                />
                {/* Cluster count label */}
                {bucket.count > 1 && (
                  <text
                    textAnchor="middle"
                    dominantBaseline="central"
                    style={{
                      fontSize: r * 0.9,
                      fontWeight: 700,
                      fill: '#fff',
                      pointerEvents: 'none',
                    }}
                  >
                    {bucket.count > 99 ? '99+' : bucket.count}
                  </text>
                )}
              </Marker>
            )
          })}
        </ZoomableGroup>
      </ComposableMap>
    </div>
  )
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
        display: 'inline-flex', alignItems: 'center', gap: '0.4rem',
        padding: '0.25rem 0.65rem', borderRadius: '999px',
        background: colors[status] + '18', border: `1px solid ${colors[status]}44`,
        fontSize: '0.78rem', fontWeight: 600, color: colors[status],
      }}
      aria-live="polite"
      aria-label={`Realtime status: ${labels[status]}`}
    >
      <span
        style={{
          width: 8, height: 8, borderRadius: '50%', background: colors[status],
          display: 'inline-block',
          animation: status === 'connected' ? 'live-pulse 1.5s ease-in-out infinite' : 'none',
        }}
      />
      {labels[status]}
    </div>
  )
}

function PinDetailPopover({
  bucket,
  onClose,
  onOpenComments,
}: {
  bucket: ClusterBucket
  onClose: () => void
  onOpenComments: (pinId: string) => void
}) {
  const sentiment = SENTIMENTS.find((s) => s.value === bucket.dominantSentiment)

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label={`Pin details: ${bucket.dominantSentiment}`}
      style={{
        position: 'fixed', bottom: '5rem', left: '50%', transform: 'translateX(-50%)',
        background: 'var(--surface)', border: '1px solid var(--line)',
        borderRadius: '12px', padding: '0.9rem 1.1rem',
        boxShadow: 'var(--shadow)', zIndex: 20, width: 'min(280px, 90vw)',
        fontSize: '0.85rem',
      }}
    >
      <button
        type="button"
        onClick={onClose}
        aria-label="Close"
        style={{ position: 'absolute', top: 8, right: 10, background: 'none', border: 'none', cursor: 'pointer', color: 'var(--muted)', fontSize: '1rem' }}
      >
        ✕
      </button>

      <p style={{ margin: '0 0 4px', fontWeight: 700, color: 'var(--text)' }}>
        {sentiment?.emoji} {sentiment?.label ?? bucket.dominantSentiment}
      </p>

      {bucket.count > 1 ? (
        <p style={{ margin: '0 0 0.6rem', color: 'var(--muted)' }}>
          {bucket.count} pins in this area
        </p>
      ) : (
        <p style={{ margin: '0 0 0.6rem', color: 'var(--muted)' }}>
          {bucket.pins[0].created_at.slice(0, 10)}
        </p>
      )}

      {bucket.count === 1 && (
        <button
          type="button"
          onClick={() => onOpenComments(bucket.pins[0].id)}
          style={{
            display: 'block', width: '100%', padding: '0.4rem 0.8rem',
            borderRadius: '8px', border: '1px solid var(--line)',
            background: 'var(--surface-soft)', color: 'var(--text)',
            cursor: 'pointer', fontSize: '0.82rem', textAlign: 'center',
          }}
        >
          💬 View comments
        </button>
      )}
    </div>
  )
}

function MoodTicker({ events }: { events: MoodLogEvent[] }) {
  if (!events.length) return null
  const doubled = [...events, ...events]

  return (
    <div
      style={{
        overflow: 'hidden', borderRadius: '8px',
        background: 'var(--surface-soft)', border: '1px solid var(--line)',
        padding: '0.5rem 0',
      }}
      aria-label="Live mood ticker"
    >
      <div
        style={{
          display: 'flex', gap: '2rem',
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
              <span style={{ width: 8, height: 8, borderRadius: '50%', background: color, display: 'inline-block', flexShrink: 0 }} />
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

  const [selectedBucket, setSelectedBucket] = useState<ClusterBucket | null>(null)
  const [commentsPanelPinId, setCommentsPanelPinId] = useState<string | null>(null)
  const [selectedSentiment, setSelectedSentiment] = useState<Sentiment>('happy')
  const [geoStatus, setGeoStatus] = useState<'idle' | 'pending' | 'denied' | 'done'>('idle')
  const [dropError, setDropError] = useState<string | null>(null)
  const [rateLimitError, setRateLimitError] = useState<string | null>(null)
  const [liveStatus, setLiveStatus] = useState<LiveStatus>('connecting')
  const [tickerEvents, setTickerEvents] = useState<MoodLogEvent[]>([])
  const [zoom, setZoom] = useState(1)
  // Track recently inserted pin IDs for pulse animation (cleared after 3s)
  const [newPinIds, setNewPinIds] = useState<Set<string>>(new Set())

  const pinsQuery = useQuery({
    queryKey: ['mood-pins'],
    queryFn: fetchPins,
    enabled: Boolean(user?.id),
  })

  // Fetch blocked user IDs for filtering
  const { data: blockedIds = [] } = useQuery({
    queryKey: ['blocked-users', user?.id],
    queryFn: async () => {
      if (!user?.id) return []
      const { data, error } = await supabase
        .from('user_blocks')
        .select('blocked_id')
        .eq('blocker_id', user.id)
      if (error) return []
      return (data ?? []).map((r) => r.blocked_id as string)
    },
    enabled: Boolean(user?.id),
  })

  useEffect(() => {
    fetchRecentMoodLogs().then(setTickerEvents)
  }, [])

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

  // Supabase Realtime — mood_pins
  useEffect(() => {
    const channel = supabase
      .channel('global-mirror-pins')
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'mood_pins' },
        (payload) => {
          const pin = payload.new as MoodPin
          // Mark as new for pulse animation, clear after 3s
          setNewPinIds((prev) => {
            const next = new Set(prev)
            next.add(pin.id)
            return next
          })
          setTimeout(() => {
            setNewPinIds((prev) => {
              const next = new Set(prev)
              next.delete(pin.id)
              return next
            })
          }, 3000)
          scheduleMapInvalidate()
        },
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

  // Supabase Realtime — mood_logs (ticker)
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
    setRateLimitError(null)

    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        try {
          await insertPin(user.id, pos.coords.latitude, pos.coords.longitude, selectedSentiment)
          // Pins are anonymous, so this achievement is unlocked at drop time.
          void unlockAchievement('global_citizen')
          setGeoStatus('done')
          scheduleMapInvalidate()
          setTimeout(() => setGeoStatus('idle'), 2000)
        } catch (err) {
          const msg = err instanceof Error ? err.message : String(err)
          if (msg.includes('rate_limit_exceeded') || msg.includes('PT429')) {
            const match = msg.match(/retry_after_seconds['":\s]+(\d+)/)
            const retrySecs = match ? Number(match[1]) : 3600
            const mins = Math.ceil(retrySecs / 60)
            setRateLimitError(`You're dropping pins too fast. Try again in ${mins} minute${mins === 1 ? '' : 's'}.`)
          } else {
            setDropError('Failed to drop pin. Please try again.')
          }
          setGeoStatus('idle')
        }
      },
      () => { setGeoStatus('denied') },
    )
  }, [user?.id, selectedSentiment, scheduleMapInvalidate])

  const pins = pinsQuery.data ?? []

  // Fetch pin-to-user mapping for blocked-user filtering
  const { data: pinUserMap = {} } = useQuery({
    queryKey: ['pin-user-map'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('user_mood_pins')
        .select('mood_pin_id, user_id')
      if (error) return {}
      const map: Record<string, string> = {}
      for (const row of (data ?? []) as { mood_pin_id: string; user_id: string }[]) {
        map[row.mood_pin_id] = row.user_id
      }
      return map
    },
    staleTime: 60_000,
  })

  // Filter out pins from blocked users
  const filteredPins = blockedIds.length > 0
    ? pins.filter((pin) => {
        const owner = pinUserMap[pin.id]
        return owner ? !blockedIds.includes(owner) : true
      })
    : pins

  return (
    <div
      className="page-wrap animate-stagger"
      style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}
    >
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', flexWrap: 'wrap' }}>
        <div>
          <h1 style={{ margin: 0 }}>Global Mirror</h1>
          <p className="muted" style={{ margin: '0.25rem 0 0' }}>
            Live mood pins shared anonymously by users worldwide.
          </p>
        </div>
        <LiveIndicator status={liveStatus} />
      </div>

      {/* Ticker */}
      {tickerEvents.length > 0 && (
        <section aria-label="Live mood events ticker">
          <MoodTicker events={tickerEvents} />
        </section>
      )}

      {/* Map */}
      <section
        className="card"
        style={{ overflow: 'hidden', position: 'relative', padding: 0, borderRadius: '12px', background: 'var(--bg-page, #d4e3f5)' }}
        aria-label="World mood map"
      >
        <WorldMap
          pins={filteredPins}
          newPinIds={newPinIds}
          zoom={zoom}
          onZoomChange={setZoom}
          onPinClick={setSelectedBucket}
        />

        {/* Legend */}
        <div
          style={{
            position: 'absolute', bottom: 10, left: 10,
            display: 'flex', flexWrap: 'wrap', gap: '0.4rem',
            background: 'var(--surface)', borderRadius: '8px',
            padding: '0.35rem 0.6rem',
            border: '1px solid var(--line)',
            fontSize: '0.72rem',
          }}
          aria-label="Mood pin legend"
        >
          {SENTIMENTS.map((s) => (
            <span
              key={s.value}
              style={{ display: 'inline-flex', alignItems: 'center', gap: '0.3rem', color: 'var(--text)' }}
            >
              <span style={{ width: 8, height: 8, borderRadius: '50%', background: s.color, display: 'inline-block' }} />
              {s.label}
            </span>
          ))}
        </div>
      </section>

      {/* Pin detail popover */}
      {selectedBucket && (
        <PinDetailPopover
          bucket={selectedBucket}
          onClose={() => setSelectedBucket(null)}
          onOpenComments={(pinId) => {
            setCommentsPanelPinId(pinId)
            setSelectedBucket(null)
          }}
        />
      )}

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
                padding: '0.4rem 0.9rem', borderRadius: '999px',
                border: `2px solid ${selectedSentiment === s.value ? s.color : 'var(--line)'}`,
                background: selectedSentiment === s.value ? s.color + '22' : 'transparent',
                color: 'var(--text)', cursor: 'pointer', fontSize: '0.85rem',
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
          <p role="alert" style={{ color: 'var(--danger)', fontSize: '0.85rem', marginBottom: '0.5rem' }}>
            {dropError}
          </p>
        )}
        {rateLimitError && (
          <p role="alert" style={{ color: '#f97316', fontSize: '0.85rem', marginBottom: '0.5rem' }}>
            ⏳ {rateLimitError}
          </p>
        )}

        <button
          type="button"
          onClick={handleDropPin}
          disabled={geoStatus === 'pending' || geoStatus === 'done'}
          style={{
            padding: '0.55rem 1.25rem', borderRadius: '10px',
            background: 'var(--brand)', color: '#fff',
            border: 'none', cursor: 'pointer', fontWeight: 600,
          }}
        >
          {geoStatus === 'pending' ? 'Getting location…' : geoStatus === 'done' ? '📍 Pinned!' : '📍 Drop pin'}
        </button>
      </section>

      {/* Comments panel */}
      {commentsPanelPinId && (
        <MoodPinCommentsPanel
          pinId={commentsPanelPinId}
          onClose={() => {
            setCommentsPanelPinId(null)
            setSelectedBucket(null)
          }}
        />
      )}

      {/* Keyframes */}
      <style>{`
        @keyframes ticker-scroll {
          0%   { transform: translateX(0); }
          100% { transform: translateX(-50%); }
        }
        @keyframes live-pulse {
          0%, 100% { opacity: 1; transform: scale(1); }
          50%       { opacity: 0.4; transform: scale(1.3); }
        }
        @keyframes lp-ring-pulse {
          0%, 100% { opacity: 0.12; transform: scale(1); }
          50%       { opacity: 0.28; transform: scale(1.04); }
        }
        @keyframes pin-pulse {
          0%   { opacity: 0.7; transform: scale(1); }
          100% { opacity: 0; transform: scale(2.5); }
        }
        /* Ocean background */
        .card[aria-label="World mood map"] {
          background: var(--bg-page, #d4e3f5);
        }
        /* Dark mode ocean */
        [data-theme='dark'] .card[aria-label="World mood map"] {
          background: #1a2d42;
        }
        /* Touch: prevent body scroll while panning the map */
        .rsm-composable-map {
          touch-action: none;
        }
        /* Map fills container on mobile */
        @media (max-width: 600px) {
          .card[aria-label="World mood map"] {
            margin: 0 -1rem;
            border-radius: 0;
          }
        }
      `}</style>
    </div>
  )
}