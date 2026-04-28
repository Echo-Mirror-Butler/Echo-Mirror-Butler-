import { useEffect } from 'react'
import { MapContainer as LeafletMap, TileLayer } from 'react-leaflet'
import MarkerClusterGroup from 'react-leaflet-cluster'
import { MoodPin } from '../../../lib/types'
import { MoodMarker } from './MoodMarker'

interface MapContainerProps {
  pins: MoodPin[]
}

export function MapContainer({ pins }: MapContainerProps) {
  // Inject Leaflet CSS on mount so we don't have to pollute index.html
  useEffect(() => {
    const link = document.createElement('link')
    link.rel = 'stylesheet'
    link.href = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css'
    link.integrity = 'sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY='
    link.crossOrigin = ''
    document.head.appendChild(link)

    return () => {
      document.head.removeChild(link)
    }
  }, [])

  return (
    <div className="w-full h-full rounded-xl overflow-hidden border border-[var(--line)] shadow-sm relative z-0">
      <LeafletMap
        center={[20, 0]}
        zoom={2}
        minZoom={2}
        style={{ height: '100%', width: '100%', background: '#a5c9f3' }} // Water color fallback
        maxBounds={[
          [-90, -180],
          [90, 180],
        ]}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          url="https://{s}.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}{r}.png"
          noWrap={true}
        />

        <MarkerClusterGroup
          chunkedLoading
          maxClusterRadius={40}
        >
          {pins.map((pin) => (
            <MoodMarker key={pin.id} pin={pin} />
          ))}
        </MarkerClusterGroup>
      </LeafletMap>
    </div>
  )
}
