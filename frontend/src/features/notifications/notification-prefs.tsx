/**
 * NotificationPrefs component — Issue #303
 *
 * Renders a notification preference toggle card for the Settings page.
 * - Opt-in/out of daily mood log reminders
 * - Configure reminder time
 * - Handles permission denied gracefully
 */
import { useEffect, useState } from 'react'
import { usePushNotifications } from '../../lib/use-push-notifications'

type Props = {
  userId: string
}

export function NotificationPrefs({ userId }: Props) {
  const { permissionState, prefs, loading, error, subscribe, unsubscribe, updateReminderTime } =
    usePushNotifications(userId)

  const [localTime, setLocalTime] = useState(prefs.reminderTime)

  const isUnsupported = permissionState === 'unsupported'
  const isDenied = permissionState === 'denied'

  useEffect(() => {
    setLocalTime(prefs.reminderTime)
  }, [prefs.reminderTime])

  const handleToggle = async () => {
    if (prefs.enabled) {
      await unsubscribe()
    } else {
      await subscribe(localTime)
    }
  }

  const handleTimeChange = async (time: string) => {
    setLocalTime(time)
    if (prefs.enabled) {
      await updateReminderTime(time)
    }
  }

  return (
    <article className="card">
      <div className="card-header">
        <h3>Daily Mood Reminders</h3>
      </div>
      <div className="card-content form-stack">
        {isUnsupported ? (
          <p className="muted" style={{ fontSize: '0.85rem' }}>
            Push notifications are not supported in your browser.
          </p>
        ) : (
          <>
            <p className="muted" style={{ fontSize: '0.85rem', margin: 0 }}>
              Get a daily reminder to log your mood and keep your streak alive.
            </p>

            {isDenied && (
              <div
                role="alert"
                style={{
                  padding: '0.6rem 0.85rem',
                  borderRadius: '8px',
                  background: '#fef2f2',
                  border: '1px solid #fecaca',
                  fontSize: '0.82rem',
                  color: '#b91c1c',
                }}
              >
                Notifications are blocked in your browser. To enable them, click the lock icon in
                your address bar and allow notifications for this site.
              </div>
            )}

            {/* Toggle */}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '1rem' }}>
              <span style={{ fontSize: '0.9rem', color: 'var(--text)' }}>
                {prefs.enabled ? '🔔 Reminders enabled' : '🔕 Reminders disabled'}
              </span>
              <button
                type="button"
                role="switch"
                aria-checked={prefs.enabled}
                onClick={() => void handleToggle()}
                disabled={loading || isDenied || isUnsupported}
                style={{
                  position: 'relative',
                  width: 44,
                  height: 24,
                  borderRadius: 999,
                  border: 'none',
                  background: prefs.enabled ? 'var(--brand)' : 'var(--line)',
                  cursor: loading || isDenied ? 'not-allowed' : 'pointer',
                  transition: 'background 0.2s',
                  flexShrink: 0,
                }}
                aria-label={prefs.enabled ? 'Disable daily reminders' : 'Enable daily reminders'}
              >
                <span
                  style={{
                    position: 'absolute',
                    top: 3,
                    left: prefs.enabled ? 23 : 3,
                    width: 18,
                    height: 18,
                    borderRadius: '50%',
                    background: '#fff',
                    transition: 'left 0.2s',
                    boxShadow: '0 1px 3px rgba(0,0,0,0.2)',
                  }}
                />
              </button>
            </div>

            {/* Reminder time picker */}
            {prefs.enabled && (
              <label style={{ display: 'flex', flexDirection: 'column', gap: '0.3rem' }}>
                <span style={{ fontSize: '0.85rem', color: 'var(--text)' }}>Reminder time</span>
                <input
                  type="time"
                  value={localTime}
                  onChange={(e) => void handleTimeChange(e.target.value)}
                  disabled={loading}
                  style={{
                    padding: '0.4rem 0.65rem',
                    borderRadius: '8px',
                    border: '1px solid var(--line)',
                    background: 'var(--surface)',
                    color: 'var(--text)',
                    fontSize: '0.9rem',
                    width: 'fit-content',
                  }}
                />
                <span className="muted" style={{ fontSize: '0.75rem' }}>
                  Time is in your local timezone
                </span>
              </label>
            )}

            {loading && (
              <p className="muted" style={{ fontSize: '0.82rem' }}>
                {prefs.enabled ? 'Disabling…' : 'Enabling notifications…'}
              </p>
            )}

            {error && (
              <p role="alert" className="error-text" style={{ fontSize: '0.82rem' }}>
                {error}
              </p>
            )}
          </>
        )}
      </div>
    </article>
  )
}
