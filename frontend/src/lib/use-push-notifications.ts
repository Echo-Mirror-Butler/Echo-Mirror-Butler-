/**
 * usePushNotifications hook — Issue #303
 *
 * Manages:
 * - Service worker registration
 * - Web Push API permission request flow
 * - Storing/removing push subscription in Supabase (push_subscriptions table)
 * - Graceful handling of permission denied
 */
import { useCallback, useEffect, useState } from 'react'
import { supabase } from './supabase'

export type PushPermissionState = 'default' | 'granted' | 'denied' | 'unsupported'

export type PushPrefs = {
  enabled: boolean
  reminderTime: string // HH:MM
}

const VAPID_PUBLIC_KEY = import.meta.env.VITE_VAPID_PUBLIC_KEY as string | undefined

function urlBase64ToUint8Array(base64String: string): Uint8Array {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4)
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/')
  const rawData = atob(base64)
  return Uint8Array.from([...rawData].map((char) => char.charCodeAt(0)))
}

async function getOrRegisterSW(): Promise<ServiceWorkerRegistration | null> {
  if (!('serviceWorker' in navigator)) return null
  try {
    const existing = await navigator.serviceWorker.getRegistration('/sw.js')
    if (existing) return existing
    return await navigator.serviceWorker.register('/sw.js', { scope: '/' })
  } catch {
    return null
  }
}

async function saveSubscriptionToSupabase(
  userId: string,
  sub: PushSubscription,
  reminderTime: string,
): Promise<void> {
  const json = sub.toJSON()
  const keys = json.keys as { p256dh: string; auth: string } | undefined
  if (!keys) throw new Error('Push subscription missing keys')

  const { error } = await supabase.from('push_subscriptions').upsert(
    {
      user_id: userId,
      endpoint: sub.endpoint,
      p256dh: keys.p256dh,
      auth: keys.auth,
      reminder_enabled: true,
      reminder_time: reminderTime,
      updated_at: new Date().toISOString(),
    },
    { onConflict: 'endpoint' },
  )
  if (error) throw error
}

async function removeSubscriptionFromSupabase(
  userId: string,
  endpoint: string,
): Promise<void> {
  await supabase
    .from('push_subscriptions')
    .delete()
    .eq('user_id', userId)
    .eq('endpoint', endpoint)
}

async function fetchUserPrefs(userId: string): Promise<PushPrefs> {
  const { data } = await supabase
    .from('push_subscriptions')
    .select('reminder_enabled, reminder_time')
    .eq('user_id', userId)
    .limit(1)
    .single()

  if (!data) return { enabled: false, reminderTime: '09:00' }
  const row = data as Record<string, unknown>
  return {
    enabled: Boolean(row.reminder_enabled),
    reminderTime: String(row.reminder_time ?? '09:00'),
  }
}

// ── Hook ──────────────────────────────────────────────────────────────────────

export function usePushNotifications(userId: string | undefined) {
  const [permissionState, setPermissionState] = useState<PushPermissionState>('default')
  const [prefs, setPrefs] = useState<PushPrefs>({ enabled: false, reminderTime: '09:00' })
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  // null = checking, true = available, false = unavailable (HTTP / private browsing)
  const [swAvailable, setSwAvailable] = useState<boolean | null>(null)
  const [subscriptionExpired, setSubscriptionExpired] = useState(false)

  // Check current permission state and SW availability on mount
  useEffect(() => {
    if (!('Notification' in window)) {
      setPermissionState('unsupported')
      setSwAvailable(false)
      return
    }
    setPermissionState(Notification.permission as PushPermissionState)

    if (!('serviceWorker' in navigator) || !window.isSecureContext) {
      setSwAvailable(false)
    } else {
      setSwAvailable(true)
    }
  }, [])

  // Load saved prefs
  useEffect(() => {
    if (!userId) return
    fetchUserPrefs(userId).then(setPrefs)
  }, [userId])

  // Detect expired subscriptions: DB says enabled but no active SW push subscription
  useEffect(() => {
    if (!userId || !prefs.enabled || !('serviceWorker' in navigator)) return
    navigator.serviceWorker
      .getRegistration('/sw.js')
      .then(async (reg) => {
        if (!reg) { setSubscriptionExpired(true); return }
        const sub = await reg.pushManager.getSubscription()
        setSubscriptionExpired(!sub)
      })
      .catch(() => {})
  }, [userId, prefs.enabled])

  const subscribe = useCallback(
    async (reminderTime: string): Promise<boolean> => {
      if (!userId) return false
      if (!('Notification' in window) || !('serviceWorker' in navigator)) {
        setPermissionState('unsupported')
        return false
      }

      setLoading(true)
      setError(null)

      try {
        // Request permission
        const permission = await Notification.requestPermission()
        setPermissionState(permission as PushPermissionState)

        if (permission !== 'granted') {
          setError('Notification permission was denied. You can enable it in your browser settings.')
          return false
        }

        const sw = await getOrRegisterSW()
        if (!sw) throw new Error('Service worker could not be registered. Try reloading the page.')

        if (!VAPID_PUBLIC_KEY) {
          throw new Error('Push notifications are not configured (missing VAPID key).')
        }

        const sub = await sw.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: urlBase64ToUint8Array(VAPID_PUBLIC_KEY).buffer as ArrayBuffer,
        })

        await saveSubscriptionToSupabase(userId, sub, reminderTime)
        setPrefs({ enabled: true, reminderTime })
        setSubscriptionExpired(false)
        return true
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to enable notifications.'
        setError(message)
        return false
      } finally {
        setLoading(false)
      }
    },
    [userId],
  )

  const unsubscribe = useCallback(async () => {
    if (!userId) return
    setLoading(true)
    setError(null)

    try {
      const sw = await getOrRegisterSW()
      if (sw) {
        const sub = await sw.pushManager.getSubscription()
        if (sub) {
          await removeSubscriptionFromSupabase(userId, sub.endpoint)
          await sub.unsubscribe()
        }
      }
      setPrefs((prev) => ({ ...prev, enabled: false }))
      setSubscriptionExpired(false)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to disable notifications.')
    } finally {
      setLoading(false)
    }
  }, [userId])

  const updateReminderTime = useCallback(
    async (time: string) => {
      if (!userId) return
      setLoading(true)
      setError(null)
      try {
        const { error: dbError } = await supabase
          .from('push_subscriptions')
          .update({ reminder_time: time, updated_at: new Date().toISOString() })
          .eq('user_id', userId)
        if (dbError) throw dbError
        setPrefs((prev) => ({ ...prev, reminderTime: time }))
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to update reminder time.')
      } finally {
        setLoading(false)
      }
    },
    [userId],
  )

  return {
    permissionState,
    prefs,
    loading,
    error,
    swAvailable,
    subscriptionExpired,
    subscribe,
    unsubscribe,
    updateReminderTime,
  }
}
