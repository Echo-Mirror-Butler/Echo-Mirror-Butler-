import { useQuery } from '@tanstack/react-query'
import { getLogImageSignedUrl } from '../../../lib/log-images'

export function LogImageThumbnail({
  path,
  alt,
  size = 44,
}: {
  path: string
  alt: string
  size?: number
}) {
  const { data: url } = useQuery({
    queryKey: ['log-image-url', path],
    queryFn: () => getLogImageSignedUrl(path),
    staleTime: 50 * 60 * 1000,
  })

  if (!url) {
    return null
  }

  return (
    <img
      src={url}
      alt={alt}
      style={{
        width: size,
        height: size,
        objectFit: 'cover',
        borderRadius: '8px',
        border: '1px solid var(--line)',
        flexShrink: 0,
      }}
    />
  )
}
