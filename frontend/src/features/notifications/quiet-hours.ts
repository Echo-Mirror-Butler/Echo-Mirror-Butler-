/**
 * quiet-hours.ts — Issue #616
 *
 * Pure helpers for the notification quiet-hours / digest-frequency feature.
 * Used by the NotificationPrefs UI for preview text, and unit-tested with
 * vitest. The same logic runs server-side in the Supabase edge functions via
 * supabase/functions/_shared/notification-scheduling.ts (kept in sync).
 *
 * Times are "HH:MM" 24h wall-clock strings in the user's local timezone.
 */

export type DigestMode = 'immediately' | 'daily'

export type QuietHoursPrefs = {
  quietHoursEnabled: boolean
  quietHoursStart: string
  quietHoursEnd: string
  moodCommentDigestMode: DigestMode
}

export const DEFAULT_QUIET_HOURS: QuietHoursPrefs = {
  quietHoursEnabled: false,
  quietHoursStart: '22:00',
  quietHoursEnd: '08:00',
  moodCommentDigestMode: 'immediately',
}

/** Convert an "HH:MM" string to minutes-since-midnight. Returns NaN if invalid. */
export function parseHHMM(value: string): number {
  const m = /^(\d{1,2}):(\d{2})$/.exec(value?.trim() ?? '')
  if (!m) return NaN
  const h = Number(m[1])
  const min = Number(m[2])
  if (h < 0 || h > 23 || min < 0 || min > 59) return NaN
  return h * 60 + min
}

/**
 * Is `nowMinutes` inside the [start, end) quiet window? Handles wrap-around
 * windows (e.g. 22:00 → 08:00). start === end is treated as an empty window.
 */
export function isWithinQuietWindow(
  nowMinutes: number,
  startMinutes: number,
  endMinutes: number,
): boolean {
  if (
    Number.isNaN(nowMinutes) ||
    Number.isNaN(startMinutes) ||
    Number.isNaN(endMinutes) ||
    startMinutes === endMinutes
  ) {
    return false
  }
  if (startMinutes < endMinutes) {
    return nowMinutes >= startMinutes && nowMinutes < endMinutes
  }
  return nowMinutes >= startMinutes || nowMinutes < endMinutes
}

/** Is the given local time inside the user's quiet hours? */
export function isInQuietHours(prefs: QuietHoursPrefs, now: Date = new Date()): boolean {
  if (!prefs.quietHoursEnabled) return false
  const nowMin = now.getHours() * 60 + now.getMinutes()
  return isWithinQuietWindow(
    nowMin,
    parseHHMM(prefs.quietHoursStart),
    parseHHMM(prefs.quietHoursEnd),
  )
}

/** Human-readable "10:00 PM" for an "HH:MM" string. */
export function formatHHMM(value: string): string {
  const mins = parseHHMM(value)
  if (Number.isNaN(mins)) return value
  const d = new Date()
  d.setHours(Math.floor(mins / 60), mins % 60, 0, 0)
  return d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })
}
