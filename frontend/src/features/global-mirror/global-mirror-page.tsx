/**
 * Global Mirror Page  (#260)
 *
 * Sections:
 * 1. Live SVG world map with real-time mood pins from Supabase Realtime
 * 2. Drop-a-pin panel (sentiment selector + geolocation)
 */
import { useCallback, useEffect, useRef, useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import type { RealtimeChannel } from '@supabase/supabase-js'
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

type Sentiment = 'happy' | 'sad' | 'stressed' | 'calm' | 'anxious'

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

// ── Coordinate helpers (match mobile MoodPinModel.anonymizeCoordinate) ─────────

function anonymize(coord: number): number {
  return Math.round(coord * 10) / 10
}

// Map geographic lon/lat to SVG x/y (simple equirectangular)
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
  const [comment, setComment] = useState('')
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
      >
        ✕
      </button>
      <p style={{ margin: '0 0 4px', fontWeight: 600, color: 'var(--text)' }}>
        {sentiment?.emoji} {sentiment?.label ?? pin.sentiment}
      </p>
      <p style={{ margin: '0 0 8px', color: 'var(--muted)' }}>
        {pin.created_at.slice(0, 10)}
      </p>
      <textarea
        placeholder="Add a comment…"
        value={comment}
        onChange={(e) => setComment(e.target.value)}
        rows={2}
        style={{
          width: '100%',
          borderRadius: '6px',
          border: '1px solid var(--line)',
          padding: '4px 6px',
          fontSize: '0.78rem',
          background: 'var(--surface-soft)',
          color: 'var(--text)',
          resize: 'none',
        }}
      />
    </div>
  )
}

// ── Page ──────────────────────────────────────────────────────────────────────

export function GlobalMirrorPage() {
  const { user } = useAuth()
  const qc = useQueryClient()
  const channelRef = useRef<RealtimeChannel | null>(null)

  const [selectedPin, setSelectedPin] = useState<{ pin: MoodPin; svgX: number; svgY: number } | null>(null)
  const [commentsPanelPinId, setCommentsPanelPinId] = useState<string | null>(null)
  const [selectedSentiment, setSelectedSentiment] = useState<Sentiment>('happy')
  const [geoStatus, setGeoStatus] = useState<'idle' | 'pending' | 'denied' | 'done'>('idle')
  const [dropError, setDropError] = useState<string | null>(null)

  const pinsQuery = useQuery({
    queryKey: ['mood-pins'],
    queryFn: fetchPins,
    enabled: Boolean(user?.id),
  })

  // Supabase Realtime subscription
  useEffect(() => {
    const channel = supabase
      .channel('mood_pins')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'mood_pins' }, () => {
        void qc.invalidateQueries({ queryKey: ['mood-pins'] })
      })
      .subscribe()
    channelRef.current = channel
    return () => { void supabase.removeChannel(channel) }
  }, [qc])

  const handleDropPin = useCallback(() => {
    if (!user?.id) return
    setGeoStatus('pending')
    setDropError(null)

    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        try {
          await insertPin(user.id, pos.coords.latitude, pos.coords.longitude, selectedSentiment)
          setGeoStatus('done')
          void qc.invalidateQueries({ queryKey: ['mood-pins'] })
          setTimeout(() => setGeoStatus('idle'), 2000)
        } catch (e) {
          setDropError('Failed to drop pin. Please try again.')
          setGeoStatus('idle')
        }
      },
      () => {
        setGeoStatus('denied')
      },
    )
  }, [user?.id, selectedSentiment, qc])

  const pins = pinsQuery.data ?? []

  return (
    <div className="page-wrap animate-stagger" style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
      <h1>Global Mirror</h1>
      <p className="muted">Live mood pins shared anonymously by users worldwide.</p>

      {/* Map */}
      <section className="card" style={{ overflow: 'hidden', position: 'relative' }}>
        <svg
          viewBox="0 0 800 400"
          style={{ width: '100%', background: 'var(--surface-soft)', borderRadius: '12px', display: 'block' }}
          aria-label="World mood map"
        >
          {/* Minimal world outline — simplified rectangle fill */}
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
                onClick={() => {
                  setSelectedPin({ pin, svgX: x, svgY: y })
                  setCommentsPanelPinId(pin.id)
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
          <p style={{ color: 'var(--danger)', fontSize: '0.85rem', marginBottom: '0.5rem' }}>
            Geolocation permission denied. Please allow location access in your browser settings.
          </p>
        )}
        {dropError && (
          <p style={{ color: 'var(--danger)', fontSize: '0.85rem', marginBottom: '0.5rem' }}>{dropError}</p>
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
    </div>
  )
}
