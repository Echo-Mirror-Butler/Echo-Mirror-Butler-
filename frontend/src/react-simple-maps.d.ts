declare module 'react-simple-maps' {
  import { ReactElement } from 'react'

  export interface ComposableMapProps {
    children?: React.ReactNode
    projection?: string
    width?: number
    height?: number
    style?: React.CSSProperties
  }

  export interface GeographiesProps {
    children?: React.ReactNode
    geography?: string | object
    parseGeographies?: (geography: any) => any[]
  }

  export interface GeographyProps {
    children?: React.ReactNode
    geography?: any
    onMouseEnter?: (event: any) => void
    onMouseLeave?: (event: any) => void
    onClick?: (event: any) => void
    style?: {
      default?: React.CSSProperties
      hover?: React.CSSProperties
      pressed?: React.CSSProperties
    }
  }

  export interface MarkerProps {
    children?: React.ReactNode
    coordinates: [number, number]
    onMouseEnter?: (event: any) => void
    onMouseLeave?: (event: any) => void
    onClick?: (event: any) => void
  }

  export interface ZoomableGroupProps {
    children?: React.ReactNode
    zoom?: number
    center?: [number, number]
    onMoveEnd?: (event: any) => void
    style?: React.CSSProperties
  }

  export const ComposableMap: React.FC<ComposableMapProps>
  export const Geographies: React.FC<GeographiesProps>
  export const Geography: React.FC<GeographyProps>
  export const Marker: React.FC<MarkerProps>
  export const ZoomableGroup: React.FC<ZoomableGroupProps>
}
