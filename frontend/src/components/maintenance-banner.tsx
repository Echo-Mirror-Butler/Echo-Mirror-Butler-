import { useEffect, useState } from 'react'
import { useMaintenanceStatus } from '../hooks/use-maintenance-status'

const DISMISS_KEY = 'echo-maintenance-dismissed'

function formatExpectedEnd(value: string | null): string | null {
  if (!value) return null
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return null
  return new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' }).format(date)
}

export function MaintenanceBanner() {
  const { data } = useMaintenanceStatus()
  const signature = data ? `${data.message ?? ''}|${data.expected_end_at ?? ''}` : ''
  const [dismissedSignature, setDismissedSignature] = useState<string | null>(null)

  useEffect(() => {
    if (typeof sessionStorage === 'undefined') return
    setDismissedSignature(sessionStorage.getItem(DISMISS_KEY))
  }, [])

  if (!data?.enabled || dismissedSignature === signature) {
    return null
  }

  const endLabel = formatExpectedEnd(data.expected_end_at)

  return (
    <div
      role="alert"
      style={{
        padding: '0.75rem 1.25rem',
        background: 'color-mix(in srgb, var(--warning) 14%, transparent)',
        borderBottom: '1px solid color-mix(in srgb, var(--warning) 35%, transparent)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: '1rem',
        flexWrap: 'wrap',
        textAlign: 'center',
      }}
    >
      <p style={{ margin: 0, fontSize: '0.9rem', color: 'var(--warning)' }}>
        <strong>Scheduled maintenance:</strong>{' '}
        {data.message?.trim() || 'The app is undergoing scheduled maintenance.'}
        {endLabel ? ` Expected to end ${endLabel}.` : ''}
      </p>
      <button
        type="button"
        onClick={() => {
          if (typeof sessionStorage !== 'undefined') {
            sessionStorage.setItem(DISMISS_KEY, signature)
          }
          setDismissedSignature(signature)
        }}
        style={{
          padding: '0.3rem 0.75rem',
          borderRadius: '8px',
          border: '1px solid color-mix(in srgb, var(--warning) 45%, transparent)',
          background: 'transparent',
          color: 'var(--warning)',
          cursor: 'pointer',
          fontSize: '0.8rem',
        }}
      >
        Dismiss
      </button>
    </div>
  )
}
