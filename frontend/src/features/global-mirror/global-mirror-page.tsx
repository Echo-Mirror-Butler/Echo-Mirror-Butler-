import { useEffect, useState } from 'react'
import { supabase } from '../../lib/supabase'

interface MoodPin {
  lat: number
  lon: number
  sentiment: string
  created_at: string
}

const SENTIMENT_COLOR: Record<string, string> = {
  positive: '#0a8a5b',
  negative: '#bb2d3b',
  neutral: '#6366f1',
}

function getSentimentColor(sentiment: string): string {
  return SENTIMENT_COLOR[sentiment.toLowerCase()] ?? '#6366f1'
}

export function GlobalMirrorPage() {
  const [pins, setPins] = useState<MoodPin[]>([])
  const [loading, setLoading] = useState(true)
  const [liveCount, setLiveCount] = useState(0)

  useEffect(() => {
    let cancelled = false

    async function loadInitialPins() {
      const { data } = await supabase
        .from('mood_pins')
        .select('lat, lon, sentiment, created_at')
        .order('created_at', { ascending: false })
        .limit(20)

      if (!cancelled && data) {
        setPins(data as MoodPin[])
        setLiveCount(data.length)
      }
      setLoading(false)
    }

    void loadInitialPins()

    const channel = supabase
      .channel('mood_pins_realtime')
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'mood_pins' },
        (payload) => {
          if (cancelled) return
          const newPin = payload.new as MoodPin
          setPins((prev) => [newPin, ...prev].slice(0, 20))
          setLiveCount((c) => c + 1)
        },
      )
      .subscribe()

    return () => {
      cancelled = true
      void supabase.removeChannel(channel)
    }
  }, [])

  const sentimentCounts = pins.reduce<Record<string, number>>((acc, pin) => {
    const key = pin.sentiment?.toLowerCase() ?? 'neutral'
    acc[key] = (acc[key] ?? 0) + 1
    return acc
  }, {})

  return (
    <div style={{ padding: '2rem', maxWidth: '900px', margin: '0 auto' }}>
      <h1 style={{ marginBottom: '0.5rem' }}>Global Mirror</h1>
      <p style={{ color: 'var(--color-muted, #6b7280)', marginBottom: '1.5rem' }}>
        {loading
          ? 'Loading live mood data…'
          : liveCount > 0
            ? `${liveCount} ${liveCount === 1 ? 'person' : 'people'} sharing right now`
            : 'No mood pins yet — be the first to share.'}
      </p>

      {/* Sentiment distribution rings */}
      {!loading && pins.length > 0 && (
        <div
          style={{
            display: 'flex',
            gap: '1rem',
            marginBottom: '2rem',
            flexWrap: 'wrap',
          }}
        >
          {Object.entries(sentimentCounts).map(([sentiment, count]) => (
            <div
              key={sentiment}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.5rem',
                padding: '0.5rem 1rem',
                borderRadius: '999px',
                background: `${getSentimentColor(sentiment)}22`,
                border: `1.5px solid ${getSentimentColor(sentiment)}`,
              }}
            >
              <span
                style={{
                  width: '10px',
                  height: '10px',
                  borderRadius: '50%',
                  background: getSentimentColor(sentiment),
                  display: 'inline-block',
                }}
              />
              <span style={{ textTransform: 'capitalize', fontWeight: 600 }}>
                {sentiment}
              </span>
              <span style={{ color: 'var(--color-muted, #6b7280)' }}>{count}</span>
            </div>
          ))}
        </div>
      )}

      {/* Live ticker strip */}
      {loading ? (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
          {[1, 2, 3].map((i) => (
            <div key={i} className="skeleton-line" />
          ))}
        </div>
      ) : pins.length === 0 ? (
        <div className="empty-state">
          <p className="muted">No mood pins have been shared yet.</p>
        </div>
      ) : (
        <div
          style={{
            display: 'flex',
            flexDirection: 'column',
            gap: '0.5rem',
            maxHeight: '480px',
            overflowY: 'auto',
          }}
        >
          {pins.map((pin, idx) => (
            <div
              key={`${pin.created_at}-${idx}`}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.75rem',
                padding: '0.75rem 1rem',
                borderRadius: '10px',
                background: 'var(--color-surface, #f9fafb)',
                border: '1px solid var(--color-border, #e5e7eb)',
                borderLeft: `4px solid ${getSentimentColor(pin.sentiment)}`,
              }}
            >
              <span
                style={{
                  width: '10px',
                  height: '10px',
                  borderRadius: '50%',
                  background: getSentimentColor(pin.sentiment),
                  flexShrink: 0,
                }}
              />
              <span style={{ fontWeight: 600, textTransform: 'capitalize' }}>
                {pin.sentiment}
              </span>
              <span style={{ color: 'var(--color-muted, #6b7280)', fontSize: '0.82rem' }}>
                {pin.lat.toFixed(2)}, {pin.lon.toFixed(2)}
              </span>
              <span
                style={{
                  marginLeft: 'auto',
                  color: 'var(--color-muted, #6b7280)',
                  fontSize: '0.78rem',
                }}
              >
                {new Date(pin.created_at).toLocaleTimeString([], {
                  hour: '2-digit',
                  minute: '2-digit',
                })}
              </span>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
