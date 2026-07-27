/**
 * notification-scheduling.ts — Issue #616
 *
 * Pure, dependency-free helpers for the quiet-hours / digest-frequency
 * send decision. No Deno or Supabase imports, so this module can be unit
 * tested from any runtime. The Deno edge functions import it directly; the
 * equivalent logic is mirrored (and unit-tested via vitest) in
 * frontend/src/features/notifications/quiet-hours.ts.
 *
 * All times are "HH:MM" 24h wall-clock strings in the user's own timezone.
 */

export type QuietHours = {
  enabled: boolean
  start: string // "HH:MM"
  end: string // "HH:MM"
}

export type DigestMode = 'immediately' | 'daily'

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
 * Minutes-since-midnight (0–1439) for a Date, expressed in an IANA timezone.
 * Falls back to the Date's UTC minutes if the timezone is unknown/unsupported.
 */
export function minutesInTimezone(date: Date, timeZone: string): number {
  try {
    const parts = new Intl.DateTimeFormat('en-US', {
      timeZone,
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
    }).formatToParts(date)
    const hour = Number(parts.find((p) => p.type === 'hour')?.value ?? '0') % 24
    const minute = Number(parts.find((p) => p.type === 'minute')?.value ?? '0')
    return hour * 60 + minute
  } catch {
    return date.getUTCHours() * 60 + date.getUTCMinutes()
  }
}

/**
 * Is `nowMinutes` inside the [start, end) quiet window? Handles windows that
 * wrap past midnight (e.g. 22:00 → 08:00). A start === end window is treated
 * as "never" (empty), not "always".
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
    // Same-day window, e.g. 01:00 → 06:00
    return nowMinutes >= startMinutes && nowMinutes < endMinutes
  }
  // Wrap-around window, e.g. 22:00 → 08:00
  return nowMinutes >= startMinutes || nowMinutes < endMinutes
}

/**
 * Should a notification for `now` be suppressed because the user is in quiet
 * hours? Evaluated in the user's timezone.
 */
export function isInQuietHours(
  now: Date,
  quiet: QuietHours,
  timeZone: string,
): boolean {
  if (!quiet?.enabled) return false
  const nowMin = minutesInTimezone(now, timeZone)
  return isWithinQuietWindow(nowMin, parseHHMM(quiet.start), parseHHMM(quiet.end))
}

/**
 * The next UTC Date at which quiet hours end, given `now`. Used to schedule a
 * suppressed notification for delivery once the window closes.
 */
export function nextQuietHoursEnd(
  now: Date,
  quiet: QuietHours,
  timeZone: string,
): Date {
  const endMin = parseHHMM(quiet.end)
  if (Number.isNaN(endMin)) return now
  const nowMin = minutesInTimezone(now, timeZone)
  // Minutes until the local wall-clock reaches `end`.
  let delta = endMin - nowMin
  if (delta <= 0) delta += 24 * 60
  return new Date(now.getTime() + delta * 60_000)
}

/**
 * Should a notification of `type` be batched into a periodic digest instead of
 * sent immediately? Only lower-priority types honour the digest mode; critical
 * types always send immediately.
 */
const DIGESTIBLE_TYPES = new Set(['mood_comment'])

export function shouldBatchIntoDigest(type: string, mode: DigestMode): boolean {
  return mode === 'daily' && DIGESTIBLE_TYPES.has(type)
}
