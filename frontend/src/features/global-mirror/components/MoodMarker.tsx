import { CircleMarker, Tooltip } from 'react-leaflet'
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
      <Tooltip direction="top" offset={[0, -10]} opacity={1}>
        <div className="flex flex-col items-center">
          <span className="font-semibold capitalize" style={{ color }}>
            {pin.sentiment}
          </span>
          <span className="text-xs text-gray-500">{timeAgo}</span>
        </div>
      </Tooltip>
    </CircleMarker>
  )
}
