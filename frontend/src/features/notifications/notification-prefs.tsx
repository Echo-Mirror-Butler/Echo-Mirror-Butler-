/**
 * NotificationPrefs component — Issue #303
 *
 * Renders a notification preference toggle card for the Settings page.
 * - Opt-in/out of daily mood log reminders
 * - Configure reminder time
 * - Three permission states: granted / denied / default
 * - Subscription expiry detection with renewal flow
 * - Weekly digest email opt-in toggle (issue #570)
 */
import { useEffect, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { usePushNotifications } from '../../lib/use-push-notifications'
import { useToast } from '../../lib/use-toast'

type Props = {
  userId: string
}

function formatTime(hhmm: string): string {
  const [h, m] = hhmm.split(':').map(Number)
  const d = new Date()
  d.setHours(h, m, 0, 0)
  return d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })
}

function formatNextReminder(reminderTime: string): string {
  const [h, m] = reminderTime.split(':').map(Number)
  const now = new Date()
  const next = new Date()
  next.setHours(h, m, 0, 0)
  const isToday = next > now
  if (!isToday) next.setDate(next.getDate() + 1)
  const label = isToday ? 'Today' : 'Tomorrow'
  return `${label} at ${next.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })}`
}

// ─────────────────────────────────────────────────────────────
// Weekly Digest Email opt-in toggle (issue #570)
// ─────────────────────────────────────────────────────────────

function WeeklyDigestToggle({ userId }: { userId: string }) {
  const queryClient = useQueryClient()
  const { showToast } = useToast()

  const { data: enabled = false, isLoading } = useQuery({
    queryKey: ['weekly-digest-pref', userId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('profiles')
        .select('weekly_digest')
        .eq('id', userId)
        .maybeSingle()
      if (error) throw error
      return (data as { weekly_digest?: boolean } | null)?.weekly_digest ?? false
    },
  })

  const mutation = useMutation({
    mutationFn: async (value: boolean) => {
      const { error } = await supabase
        .from('profiles')
        .update({ weekly_digest: value })
        .eq('id', userId)
      if (error) throw error
      return value
    },
    onSuccess: (value) => {
      queryClient.setQueryData(['weekly-digest-pref', userId], value)
      showToast(
        value
          ? "You'll receive a weekly mood summary every Sunday evening"
          : 'Weekly digest emails turned off',
        value ? 'success' : 'info',
      )
    },
    onError: () => {
      showToast('Failed to update weekly digest preference', 'error')
    },
  })

  return (
    <article className="card" style={{ marginTop: '1rem' }}>
      <div className="card-header">
        <h3>Weekly Mood Report</h3>
      </div>
      <div className="card-content form-stack">
        <p className="muted" style={{ fontSize: '0.85rem', margin: 0 }}>
          Receive a weekly email every Sunday evening with your avg mood score, trend, top habits,
          and an AI reflection. Off by default.
        </p>

        {/* Toggle row */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: '1rem',
          }}
        >
          <span style={{ fontSize: '0.9rem', color: 'var(--text)' }}>
            {enabled ? '📬 Weekly digest enabled' : '📭 Weekly digest disabled'}
          </span>
          <button
            type="button"
            role="switch"
            aria-checked={enabled}
            onClick={() => mutation.mutate(!enabled)}
            disabled={isLoading || mutation.isPending}
            style={{
              position: 'relative',
              width: 44,
              height: 24,
              borderRadius: 999,
              border: 'none',
              background: enabled ? 'var(--brand)' : 'var(--line)',
              cursor: isLoading || mutation.isPending ? 'not-allowed' : 'pointer',
              transition: 'background 0.2s',
              flexShrink: 0,
              opacity: isLoading || mutation.isPending ? 0.6 : 1,
            }}
            aria-label={enabled ? 'Disable weekly digest email' : 'Enable weekly digest email'}
          >
            <span
              style={{
                position: 'absolute',
                top: 3,
                left: enabled ? 23 : 3,
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

        {enabled && (
          <p className="muted" style={{ fontSize: '0.8rem', margin: 0 }}>
            📅 Next digest: Sunday at 20:00 UTC
          </p>
        )}

        {mutation.isError && (
          <p role="alert" className="error-text" style={{ fontSize: '0.82rem' }}>
            Failed to update preference. Please try again.
          </p>
        )}
      </div>
    </article>
  )
}

export function NotificationPrefs({ userId }: Props) {
  const {
    permissionState,
    prefs,
    loading,
    error,
    swAvailable,
    subscriptionExpired,
    subscribe,
    unsubscribe,
    updateReminderTime,
  } = usePushNotifications(userId)

  const { showToast } = useToast()

  const [localTime, setLocalTime] = useState(prefs.reminderTime)

  const isUnsupported = permissionState === 'unsupported'
  const isDenied = permissionState === 'denied'
  const isGranted = permissionState === 'granted'
  const isDefault = permissionState === 'default'
  const swUnavailable = swAvailable === false && !isUnsupported

  useEffect(() => {
    setLocalTime(prefs.reminderTime)
  }, [prefs.reminderTime])

  const handleToggle = async () => {
    if (prefs.enabled) {
      await unsubscribe()
      showToast('Reminders turned off', 'info')
    } else {
      const success = await subscribe(localTime)
      if (success) {
        showToast(`You'll receive a reminder at ${formatTime(localTime)} each day`, 'success')
      }
    }
  }

  const handleRenew = async () => {
    const success = await subscribe(localTime)
    if (success) {
      showToast(`You'll receive a reminder at ${formatTime(localTime)} each day`, 'success')
    }
  }

  const handleTimeChange = async (time: string) => {
    setLocalTime(time)
    if (prefs.enabled) {
      await updateReminderTime(time)
    }
  }

  return (
    <>
    <article className="card">
      <div className="card-header">
        <h3>Daily Mood Reminders</h3>
      </div>
      <div className="card-content form-stack">
        {isUnsupported ? (
          <p className="muted" style={{ fontSize: '0.85rem' }}>
            Push notifications are not supported in your browser.
          </p>
        ) : swUnavailable ? (
          <p className="muted" style={{ fontSize: '0.85rem' }}>
            Push notifications require a secure (HTTPS) connection and are not available in private
            browsing mode. Try opening this page in a regular browser window over HTTPS.
          </p>
        ) : (
          <>
            {/* Permission state */}
            {isDenied && (
              <div
                role="alert"
                style={{
                  padding: '0.6rem 0.85rem',
                  borderRadius: '8px',
                  background: '#fef3cd',
                  border: '1px solid #fde68a',
                  fontSize: '0.82rem',
                  color: '#92400e',
                }}
              >
                <strong>Notifications are blocked</strong> in your browser. To enable them:
                <ul style={{ margin: '0.4rem 0 0', paddingLeft: '1.2rem' }}>
                  <li>
                    <strong>Chrome / Edge:</strong> Click the lock icon in the address bar → Site
                    settings → Notifications → Allow
                  </li>
                  <li>
                    <strong>Firefox:</strong> Click the shield icon → Connection settings →
                    Permissions → Allow Notifications
                  </li>
                  <li>
                    <strong>Safari:</strong> Safari menu → Settings for This Website → Notifications
                    → Allow
                  </li>
                </ul>
              </div>
            )}

            {isDefault && (
              <p className="muted" style={{ fontSize: '0.85rem', margin: 0 }}>
                Enable to receive daily mood reminders
              </p>
            )}

            {isGranted && (
              <p className="muted" style={{ fontSize: '0.85rem', margin: 0 }}>
                Get a daily reminder to log your mood and keep your streak alive.
              </p>
            )}

            {/* Toggle row */}
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                gap: '1rem',
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <span style={{ fontSize: '0.9rem', color: 'var(--text)' }}>
                  {prefs.enabled ? '🔔 Reminders enabled' : '🔕 Reminders disabled'}
                </span>
                {isGranted && (
                  <span
                    style={{
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: '0.25rem',
                      padding: '0.15rem 0.5rem',
                      borderRadius: '999px',
                      background: '#dcfce7',
                      border: '1px solid #bbf7d0',
                      color: '#15803d',
                      fontSize: '0.75rem',
                      fontWeight: 600,
                    }}
                  >
                    ✅ Notifications enabled
                  </span>
                )}
              </div>
              <button
                type="button"
                role="switch"
                aria-checked={prefs.enabled}
                onClick={() => void handleToggle()}
                disabled={loading || isDenied || isUnsupported || swUnavailable}
                style={{
                  position: 'relative',
                  width: 44,
                  height: 24,
                  borderRadius: 999,
                  border: 'none',
                  background: prefs.enabled ? 'var(--brand)' : 'var(--line)',
                  cursor: loading || isDenied || swUnavailable ? 'not-allowed' : 'pointer',
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

            {/* Expired subscription banner */}
            {subscriptionExpired && prefs.enabled && (
              <div
                role="alert"
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  gap: '1rem',
                  padding: '0.6rem 0.85rem',
                  borderRadius: '8px',
                  background: '#fef3cd',
                  border: '1px solid #fde68a',
                  fontSize: '0.82rem',
                  color: '#92400e',
                }}
              >
                <span>Your reminder subscription needs to be renewed.</span>
                <button
                  type="button"
                  onClick={() => void handleRenew()}
                  disabled={loading}
                  style={{
                    padding: '0.3rem 0.75rem',
                    borderRadius: '6px',
                    border: '1px solid #d97706',
                    background: '#d97706',
                    color: '#fff',
                    fontSize: '0.8rem',
                    fontWeight: 600,
                    cursor: loading ? 'not-allowed' : 'pointer',
                    flexShrink: 0,
                  }}
                >
                  Renew
                </button>
              </div>
            )}

            {/* Reminder time picker + next reminder */}
            {prefs.enabled && !subscriptionExpired && (
              <>
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
                <p className="muted" style={{ fontSize: '0.82rem', margin: 0 }}>
                  Next reminder: {formatNextReminder(prefs.reminderTime)}
                </p>
              </>
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
    <WeeklyDigestToggle userId={userId} />
    </>
  )
}
