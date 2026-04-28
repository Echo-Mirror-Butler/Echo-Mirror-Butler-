import { CircleMarker, Popup } from 'react-leaflet'
import { useState } from 'react'
import { formatDistanceToNow } from 'date-fns'
import { MoodPin } from '../../../lib/types'

const SENTIMENT_COLORS = {
  happy: '#22c55e',
  neutral: '#f59e0b',
  sad: '#3b82f6',
}

interface MoodMarkerProps {
  pin: MoodPin
}

export function MoodMarker({ pin }: MoodMarkerProps) {
  const color = SENTIMENT_COLORS[pin.sentiment] || '#94a3b8'
  const timeAgo = formatDistanceToNow(new Date(pin.created_at), { addSuffix: true })
  const [comment, setComment] = useState('')
  
  // Use a slight jitter if you have multiple pins exactly at the same 1 decimal place lat/lon
  // react-leaflet-cluster will group them, but if zoomed in all the way, they might overlap.
  // We'll trust react-leaflet-cluster to handle density for now.

  return (
    <CircleMarker
      center={[pin.grid_lat, pin.grid_lon]}
      radius={8}
      pathOptions={{
        fillColor: color,
        color: '#ffffff', // white border
        weight: 1,
        opacity: 1,
        fillOpacity: 0.8,
      }}
    >
      <Popup className="mood-popup">
        <div className="flex flex-col gap-2 min-w-[200px]">
          <div className="flex justify-between items-center">
            <span className="font-semibold capitalize text-base" style={{ color }}>
              {pin.sentiment}
            </span>
            <span className="text-xs text-gray-500">{timeAgo}</span>
          </div>
          <textarea
            placeholder="Add a comment…"
            value={comment}
            onChange={(e) => setComment(e.target.value)}
            rows={2}
            className="w-full rounded-md border border-[var(--line)] p-2 text-sm bg-[var(--surface-soft)] text-[var(--text)] resize-none focus:outline-none focus:border-[var(--brand)]"
          />
        </div>
      </Popup>
    </CircleMarker>
  )
}
