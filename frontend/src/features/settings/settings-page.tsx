/**
 * Settings Page (#304, #439)
 *
 * - Avatar upload with live circular preview before confirming, remove option
 * - Display name field
 * - Timezone searchable combobox with UTC offset labels, auto-detect on first load
 * - Account deletion grace period (7-day window, banner + cancel)
 * - Inline password change form with strength meter
 * - Data export with progress indicator
 * - Toast notifications for success/error feedback
 * - Leaderboard privacy toggle
 */
import { useEffect, useRef, useState, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import { useAuth } from '../../lib/auth-context'
import { useTheme } from '../../lib/use-theme'
import { useToast } from '../../lib/use-toast'
import { supabase } from '../../lib/supabase'
import { NotificationPrefs } from '../notifications/notification-prefs'
import { jsPDF } from 'jspdf'

// ── Types ─────────────────────────────────────────────────────────────────────

type Profile = {
  display_name: string | null
  avatar_url: string | null
  timezone: string
  leaderboard_anonymous?: boolean
}

// ── Constants ─────────────────────────────────────────────────────────────────

const MAX_AVATAR_SIZE_BYTES = 2 * 1024 * 1024
const ALLOWED_AVATAR_TYPES = ['image/png', 'image/jpeg', 'image/jpg']
const AVATAR_BUCKET = 'avatars'
const GRACE_PERIOD_DAYS = 7

// ── Helpers ───────────────────────────────────────────────────────────────────

function getSupportedTimezones(): string[] {
  try {
    // @ts-expect-error — Intl.supportedValuesOf is available in modern browsers
    return (Intl.supportedValuesOf('timeZone') as string[]).sort()
  } catch {
    return [
      'UTC',
      'America/New_York',
      'America/Chicago',
      'America/Denver',
      'America/Los_Angeles',
      'Europe/London',
      'Europe/Paris',
      'Europe/Berlin',
      'Asia/Tokyo',
      'Asia/Shanghai',
      'Asia/Kolkata',
      'Australia/Sydney',
      'Africa/Lagos',
    ]
  }
}

const ALL_TIMEZONES = getSupportedTimezones()

function getUTCOffset(tz: string): string {
  try {
    const parts = new Intl.DateTimeFormat('en', {
      timeZone: tz,
      timeZoneName: 'shortOffset',
    }).formatToParts(new Date())
    const offset = parts.find((p) => p.type === 'timeZoneName')?.value ?? 'UTC'
    return offset.replace('GMT', 'UTC')
  } catch {
    return 'UTC'
  }
}

function passwordStrength(pw: string): { score: number; label: string; color: string } {
  let score = 0
  if (pw.length >= 8) score++
  if (pw.length >= 12) score++
  if (/[A-Z]/.test(pw)) score++
  if (/[0-9]/.test(pw)) score++
  if (/[^A-Za-z0-9]/.test(pw)) score++
  if (score <= 1) return { score, label: 'Weak', color: 'var(--danger)' }
  if (score <= 3) return { score, label: 'Fair', color: 'var(--warning)' }
  return { score, label: 'Strong', color: 'var(--success)' }
}

async function fetchProfile(userId: string): Promise<Profile> {
  const { data, error } = await supabase
    .from('profiles')
    .select('display_name, avatar_url, timezone, leaderboard_anonymous')
    .eq('id', userId)
    .single()

  if (error || !data) {
    return { display_name: null, avatar_url: null, timezone: 'UTC', leaderboard_anonymous: false }
  }

  return {
    display_name: (data as Record<string, unknown>).display_name as string | null,
    avatar_url: (data as Record<string, unknown>).avatar_url as string | null,
    timezone: ((data as Record<string, unknown>).timezone as string) ?? 'UTC',
    leaderboard_anonymous: ((data as Record<string, unknown>).leaderboard_anonymous as boolean) ?? false,
  }
}

async function upsertProfile(userId: string, updates: Partial<Profile>): Promise<void> {
  const { error } = await supabase
    .from('profiles')
    .upsert({ id: userId, ...updates, updated_at: new Date().toISOString() })
  if (error) throw error
}

async function uploadAvatar(userId: string, file: File): Promise<string> {
  const ext = file.name.split('.').pop() ?? 'jpg'
  const path = `${userId}/avatar.${ext}`

  const { error: uploadError } = await supabase.storage
    .from(AVATAR_BUCKET)
    .upload(path, file, { upsert: true, contentType: file.type })

  if (uploadError) throw uploadError

  const { data } = supabase.storage.from(AVATAR_BUCKET).getPublicUrl(path)
  return `${data.publicUrl}?t=${Date.now()}`
}

// ── Avatar upload component ───────────────────────────────────────────────────

function AvatarUpload({
  avatarUrl,
  displayName,
  onConfirmUpload,
  onRemove,
  uploading,
}: {
  avatarUrl: string | null
  displayName: string | null
  onConfirmUpload: (file: File) => void
  onRemove: () => void
  uploading: boolean
}) {
  const inputRef = useRef<HTMLInputElement>(null)
  const [dragOver, setDragOver] = useState(false)
  const [fileError, setFileError] = useState<string | null>(null)
  const [pendingFile, setPendingFile] = useState<File | null>(null)
  const [previewUrl, setPreviewUrl] = useState<string | null>(null)

  const initials = displayName
    ? displayName.trim().split(' ').map((w) => w[0]).join('').toUpperCase().slice(0, 2)
    : 'U'

  const displayedUrl = previewUrl ?? avatarUrl

  function selectFile(file: File) {
    setFileError(null)
    if (!ALLOWED_AVATAR_TYPES.includes(file.type)) {
      setFileError('Only PNG or JPG files are allowed.')
      return
    }
    if (file.size > MAX_AVATAR_SIZE_BYTES) {
      setFileError(`File is ${(file.size / 1024 / 1024).toFixed(1)} MB — max is 2 MB.`)
      return
    }
    const url = URL.createObjectURL(file)
    setPendingFile(file)
    setPreviewUrl(url)
  }

  function cancelPreview() {
    if (previewUrl) URL.revokeObjectURL(previewUrl)
    setPendingFile(null)
    setPreviewUrl(null)
    setFileError(null)
  }

  function confirmUpload() {
    if (!pendingFile) return
    onConfirmUpload(pendingFile)
    if (previewUrl) URL.revokeObjectURL(previewUrl)
    setPendingFile(null)
    setPreviewUrl(null)
  }

  return (
    <div style={{ display: 'flex', alignItems: 'flex-start', gap: '1.25rem', flexWrap: 'wrap' }}>
      {/* Circular avatar / preview */}
      <div
        style={{
          width: 80,
          height: 80,
          borderRadius: '50%',
          overflow: 'hidden',
          background: 'var(--brand)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexShrink: 0,
          border: previewUrl ? '2px solid var(--brand)' : '2px solid var(--line)',
          outline: previewUrl ? '2px solid var(--brand-strong)' : 'none',
          outlineOffset: 2,
        }}
      >
        {displayedUrl ? (
          <img
            src={displayedUrl}
            alt={displayName ?? 'Avatar preview'}
            style={{ width: '100%', height: '100%', objectFit: 'cover' }}
          />
        ) : (
          <span style={{ color: '#fff', fontWeight: 700, fontSize: '1.5rem' }}>{initials}</span>
        )}
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: '0.4rem' }}>
        {pendingFile ? (
          <>
            <p style={{ margin: 0, fontSize: '0.82rem', color: 'var(--muted)' }}>
              Preview — save to apply
            </p>
            <div style={{ display: 'flex', gap: '0.5rem' }}>
              <button type="button" onClick={confirmUpload} disabled={uploading}>
                {uploading ? 'Uploading…' : 'Save photo'}
              </button>
              <button type="button" onClick={cancelPreview} disabled={uploading}>
                Cancel
              </button>
            </div>
          </>
        ) : (
          <>
            <button
              type="button"
              onClick={() => inputRef.current?.click()}
              onDragOver={(e) => { e.preventDefault(); setDragOver(true) }}
              onDragLeave={() => setDragOver(false)}
              onDrop={(e) => {
                e.preventDefault()
                setDragOver(false)
                const file = e.dataTransfer.files[0]
                if (file) selectFile(file)
              }}
              style={{
                padding: '0.4rem 0.9rem',
                borderRadius: '8px',
                border: `1px dashed ${dragOver ? 'var(--brand)' : 'var(--line)'}`,
                background: dragOver ? 'var(--surface-soft)' : 'transparent',
                cursor: 'pointer',
                fontSize: '0.85rem',
                color: 'var(--text)',
              }}
            >
              Upload photo
            </button>
            {avatarUrl && (
              <button
                type="button"
                onClick={onRemove}
                style={{
                  padding: '0.35rem 0.9rem',
                  borderRadius: '8px',
                  border: '1px solid var(--line)',
                  background: 'transparent',
                  cursor: 'pointer',
                  fontSize: '0.82rem',
                  color: 'var(--danger)',
                }}
              >
                Remove photo
              </button>
            )}
          </>
        )}

        <p className="muted" style={{ margin: 0, fontSize: '0.75rem' }}>
          PNG or JPG, max 2 MB
        </p>
        {fileError && (
          <p role="alert" style={{ color: 'var(--danger)', fontSize: '0.78rem', margin: 0 }}>
            {fileError}
          </p>
        )}

        <input
          ref={inputRef}
          type="file"
          accept="image/png,image/jpeg"
          style={{ display: 'none' }}
          aria-label="Upload avatar image"
          onChange={(e) => {
            const file = e.target.files?.[0]
            if (file) selectFile(file)
            e.target.value = ''
          }}
        />
      </div>
    </div>
  )
}

// ── Timezone combobox ─────────────────────────────────────────────────────────

function TimezoneCombobox({
  value,
  onChange,
}: {
  value: string
  onChange: (tz: string) => void
}) {
  const [search, setSearch] = useState('')
  const [open, setOpen] = useState(false)
  const containerRef = useRef<HTMLDivElement>(null)

  const filtered = search.trim()
    ? ALL_TIMEZONES.filter((tz) =>
        tz.toLowerCase().includes(search.toLowerCase()),
      ).slice(0, 80)
    : ALL_TIMEZONES.slice(0, 80)

  function select(tz: string) {
    onChange(tz)
    setSearch('')
    setOpen(false)
  }

  // Close on outside click
  useEffect(() => {
    function handler(e: MouseEvent) {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        setOpen(false)
      }
    }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [])

  return (
    <div ref={containerRef} style={{ position: 'relative' }}>
      <input
        type="text"
        value={open ? search : `${value}  ${getUTCOffset(value)}`}
        placeholder="Search timezone…"
        onFocus={() => { setOpen(true); setSearch('') }}
        onChange={(e) => setSearch(e.target.value)}
        aria-label="Timezone search"
        aria-haspopup="listbox"
        aria-expanded={open}
        autoComplete="off"
      />
      {open && (
        <ul
          role="listbox"
          style={{
            position: 'absolute',
            top: '100%',
            left: 0,
            right: 0,
            zIndex: 100,
            background: 'var(--surface)',
            border: '1px solid var(--line)',
            borderRadius: '8px',
            maxHeight: '220px',
            overflowY: 'auto',
            margin: '2px 0 0',
            padding: 0,
            listStyle: 'none',
            boxShadow: 'var(--shadow)',
          }}
        >
          {filtered.length === 0 && (
            <li style={{ padding: '0.5rem 0.75rem', color: 'var(--muted)', fontSize: '0.85rem' }}>
              No matches
            </li>
          )}
          {filtered.map((tz) => (
            <li
              key={tz}
              role="option"
              aria-selected={tz === value}
              onClick={() => select(tz)}
              style={{
                padding: '0.45rem 0.75rem',
                cursor: 'pointer',
                fontSize: '0.88rem',
                display: 'flex',
                justifyContent: 'space-between',
                gap: '0.5rem',
                background: tz === value ? 'var(--surface-soft)' : 'transparent',
                color: 'var(--text)',
              }}
              onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.background = 'var(--surface-soft)' }}
              onMouseLeave={(e) => {
                (e.currentTarget as HTMLElement).style.background =
                  tz === value ? 'var(--surface-soft)' : 'transparent'
              }}
            >
              <span>{tz}</span>
              <span style={{ color: 'var(--muted)', fontSize: '0.8rem', flexShrink: 0 }}>
                {getUTCOffset(tz)}
              </span>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}

// ── Inline password change ────────────────────────────────────────────────────

function PasswordChangeSection() {
  const { showToast } = useToast()
  const [newPassword, setNewPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const strength = passwordStrength(newPassword)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError(null)
    if (newPassword.length < 8) {
      setError('Password must be at least 8 characters.')
      return
    }
    if (newPassword !== confirmPassword) {
      setError('Passwords do not match.')
      return
    }
    setSaving(true)
    try {
      const { error: updateError } = await supabase.auth.updateUser({ password: newPassword })
      if (updateError) throw updateError
      showToast('Password updated.', 'success')
      setNewPassword('')
      setConfirmPassword('')
    } catch (err) {
      showToast(err instanceof Error ? err.message : 'Password update failed.', 'error')
    } finally {
      setSaving(false)
    }
  }

  return (
    <article className="card">
      <div className="card-header">
        <h3>Change password</h3>
      </div>
      <div className="card-content">
        <form onSubmit={(e) => void handleSubmit(e)} style={{ display: 'flex', flexDirection: 'column', gap: '0.6rem' }}>
          <label>
            New password
            <input
              type="password"
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              minLength={8}
              placeholder="Min. 8 characters"
              autoComplete="new-password"
            />
          </label>

          {newPassword.length > 0 && (
            <div>
              <div
                style={{
                  height: 4,
                  borderRadius: 2,
                  background: 'var(--line)',
                  overflow: 'hidden',
                }}
              >
                <div
                  style={{
                    width: `${(strength.score / 5) * 100}%`,
                    height: '100%',
                    background: strength.color,
                    transition: 'width 0.3s ease',
                  }}
                />
              </div>
              <p style={{ margin: '0.2rem 0 0', fontSize: '0.78rem', color: strength.color }}>
                {strength.label}
              </p>
            </div>
          )}

          <label>
            Confirm new password
            <input
              type="password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              placeholder="Repeat new password"
              autoComplete="new-password"
            />
          </label>

          {error && (
            <p role="alert" className="error-text" style={{ margin: 0 }}>
              {error}
            </p>
          )}

          <button type="submit" disabled={saving || !newPassword || !confirmPassword}>
            {saving ? 'Updating…' : 'Update password'}
          </button>
        </form>
      </div>
    </article>
  )
}

// ── Page ──────────────────────────────────────────────────────────────────────

type ExportFormat = 'json' | 'csv'

export function SettingsPage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { user, session, signOut } = useAuth()
  const { theme, setTheme } = useTheme()

  const [profile, setProfile] = useState<Profile>({ display_name: null, avatar_url: null, timezone: 'UTC', leaderboard_anonymous: false })
  const [profileLoading, setProfileLoading] = useState(true)
  const [displayName, setDisplayName] = useState('')
  const [timezone, setTimezone] = useState('')
  const [profileSaving, setProfileSaving] = useState(false)
  const [avatarUploading, setAvatarUploading] = useState(false)

  const { showToast } = useToast()

  // Delete / grace period state
  const [deleteLoading, setDeleteLoading] = useState(false)
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)
  const [deleteConfirmEmail, setDeleteConfirmEmail] = useState('')
  const [deleteError, setDeleteError] = useState<string | null>(null)
  const [scheduledDeletionAt, setScheduledDeletionAt] = useState<Date | null>(null)
  const [cancelDeletionLoading, setCancelDeletionLoading] = useState(false)

  const [exportFormat, setExportFormat] = useState<ExportFormat>('json')
  const [exportLoading, setExportLoading] = useState(false)
  const [exportError, setExportError] = useState<string | null>(null)
  const [exportProgress, setExportProgress] = useState<string | null>(null)

  useEffect(() => {
    if (!user?.id) return
    setProfileLoading(true)
    fetchProfile(user.id).then((p) => {
      setProfile(p)
      setDisplayName(p.display_name ?? '')
      // Auto-detect timezone if none saved
      const savedTz = p.timezone && p.timezone !== 'UTC' ? p.timezone : null
      setTimezone(savedTz ?? Intl.DateTimeFormat().resolvedOptions().timeZone ?? 'UTC')
      setProfileLoading(false)
    })

    // Check grace period
    const scheduledAt = user.user_metadata?.scheduled_deletion_at
    if (scheduledAt) {
      setScheduledDeletionAt(new Date(scheduledAt))
    }
  }, [user?.id, user?.user_metadata?.scheduled_deletion_at])

  if (!user) return null

  // ── Handlers ────────────────────────────────────────────────────────────────

  const handleExport = async () => {
    setExportError(null)
    setExportProgress('Preparing your data…')
    setExportLoading(true)

    try {
      const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
      const res = await fetch(
        `${supabaseUrl}/functions/v1/export-user-data?format=${exportFormat}`,
        {
          method: 'GET',
          headers: { Authorization: `Bearer ${session?.access_token ?? ''}` },
        },
      )

      if (res.status === 429) {
        const body = await res.json()
        const mins = Math.ceil((body.retry_after_seconds ?? 3600) / 60)
        setExportError(`Export available again in ${mins} minute${mins === 1 ? '' : 's'}`)
        return
      }

      if (!res.ok) {
        const body = await res.json().catch(() => ({ error: 'Export failed' }))
        setExportError(body.error ?? 'Export failed')
        return
      }

      setExportProgress('Downloading…')
      const blob = await res.blob()
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download =
        res.headers.get('content-disposition')?.match(/filename="(.+)"/)?.[1] ??
        `echomirror-export.${exportFormat}`
      document.body.appendChild(a)
      a.click()
      a.remove()
      URL.revokeObjectURL(url)
      showToast('Export downloaded', 'success')
    } catch (err) {
      showToast(err instanceof Error ? err.message : 'Export failed', 'error')
    } finally {
      setExportLoading(false)
      setExportProgress(null)
    }
  }

  const handleExportPDF = async () => {
    setExportError(null)
    setExportLoading(true)
    setExportProgress('Building your PDF… fetching entries')

    try {
      const { data: entries, error: entriesErr } = await supabase
        .from('log_entries')
        .select('date, mood, habits, notes')
        .eq('user_id', user.id)
        .order('date', { ascending: false })
        .limit(300)
      if (entriesErr) throw entriesErr

      setExportProgress('Building your PDF… fetching insights')
      const { data: insights, error: insightsErr } = await supabase
        .from('insights')
        .select('prediction, suggestions, created_at')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false })
        .limit(3)
      if (insightsErr) throw insightsErr

      setExportProgress('Building your PDF… finishing')

      const MOOD_EMOJI: Record<number, string> = { 1: '😢', 2: '😕', 3: '😐', 4: '🙂', 5: '😄' }
      const safeEntries = entries ?? []
      const safeInsights = insights ?? []

      const totalEntries = safeEntries.length
      const avgMood =
        totalEntries > 0
          ? (
              safeEntries.filter((e) => e.mood != null).reduce((s, e) => s + (e.mood ?? 0), 0) /
              safeEntries.filter((e) => e.mood != null).length
            ).toFixed(2)
          : 'N/A'
      const dateRange =
        totalEntries > 0
          ? `${safeEntries[safeEntries.length - 1].date} → ${safeEntries[0].date}`
          : 'No entries'

      const doc = new jsPDF({ unit: 'pt', format: 'a4' })
      const W = doc.internal.pageSize.getWidth()
      const H = doc.internal.pageSize.getHeight()
      const margin = 48
      const contentW = W - margin * 2
      const BRAND = [20, 99, 255] as const
      const FOOTER_TEXT = 'Generated locally by EchoMirror — your data never left your device'

      const addFooter = () => {
        doc.setFontSize(8)
        doc.setTextColor(120, 130, 145)
        doc.text(FOOTER_TEXT, W / 2, H - 20, { align: 'center' })
      }

      // ── Cover page ──────────────────────────────────────────
      doc.setFillColor(...BRAND)
      doc.rect(0, 0, W, 6, 'F')

      doc.setFontSize(28)
      doc.setTextColor(...BRAND)
      doc.setFont('helvetica', 'bold')
      doc.text('EchoMirror', margin, 80)

      doc.setFontSize(16)
      doc.setTextColor(30, 40, 55)
      doc.setFont('helvetica', 'normal')
      doc.text('Mood Journal Export', margin, 108)

      doc.setDrawColor(210, 220, 235)
      doc.line(margin, 122, W - margin, 122)

      const coverFields = [
        ['Email', user.email ?? ''],
        ['Date range', dateRange],
        ['Total entries', String(totalEntries)],
        ['Average mood', avgMood],
      ]
      let y = 152
      for (const [label, value] of coverFields) {
        doc.setFontSize(10)
        doc.setTextColor(90, 100, 115)
        doc.setFont('helvetica', 'bold')
        doc.text(label, margin, y)
        doc.setFont('helvetica', 'normal')
        doc.setTextColor(30, 40, 55)
        doc.text(value, margin + 120, y)
        y += 24
      }

      addFooter()

      // ── Mood distribution page ──────────────────────────────
      doc.addPage()
      doc.setFillColor(...BRAND)
      doc.rect(0, 0, W, 6, 'F')

      doc.setFontSize(16)
      doc.setTextColor(...BRAND)
      doc.setFont('helvetica', 'bold')
      doc.text('Mood Distribution', margin, 50)

      const moodCounts: Record<number, number> = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 }
      for (const e of safeEntries) {
        if (e.mood != null) moodCounts[e.mood] = (moodCounts[e.mood] ?? 0) + 1
      }
      const maxCount = Math.max(...Object.values(moodCounts), 1)
      const barMaxW = contentW - 60
      y = 80
      const emojiMap: Record<number, string> = { 1: '1 Terrible', 2: '2 Bad', 3: '3 Okay', 4: '4 Good', 5: '5 Great' }
      for (let score = 1; score <= 5; score++) {
        const count = moodCounts[score]
        const barW = (count / maxCount) * barMaxW
        doc.setFontSize(10)
        doc.setFont('helvetica', 'normal')
        doc.setTextColor(30, 40, 55)
        doc.text(emojiMap[score], margin, y + 10)
        doc.setFillColor(...BRAND)
        if (barW > 0) doc.rect(margin + 68, y - 2, barW, 14, 'F')
        doc.setTextColor(80, 90, 105)
        doc.text(String(count), margin + 68 + barW + 6, y + 10)
        y += 28
      }

      addFooter()

      // ── Entries pages (10 per page) ─────────────────────────
      const PAGE_SIZE = 10
      const pages = Math.ceil(safeEntries.length / PAGE_SIZE)
      for (let p = 0; p < pages; p++) {
        doc.addPage()
        doc.setFillColor(...BRAND)
        doc.rect(0, 0, W, 6, 'F')

        doc.setFontSize(14)
        doc.setTextColor(...BRAND)
        doc.setFont('helvetica', 'bold')
        doc.text(`Mood Entries (${p + 1}/${pages})`, margin, 46)

        y = 72
        const slice = safeEntries.slice(p * PAGE_SIZE, (p + 1) * PAGE_SIZE)
        for (const entry of slice) {
          if (y > H - 80) break
          const emoji = entry.mood != null ? (MOOD_EMOJI[entry.mood] ?? String(entry.mood)) : '—'
          doc.setFontSize(10)
          doc.setFont('helvetica', 'bold')
          doc.setTextColor(30, 40, 55)
          doc.text(`${entry.date}  ${emoji}`, margin, y)

          if (Array.isArray(entry.habits) && entry.habits.length > 0) {
            doc.setFont('helvetica', 'normal')
            doc.setFontSize(9)
            doc.setTextColor(70, 90, 115)
            const habitsLine = entry.habits.join(', ')
            const wrapped = doc.splitTextToSize(habitsLine, contentW)
            doc.text(wrapped, margin, y + 13)
            y += 13 * wrapped.length
          }

          if (entry.notes) {
            doc.setFont('helvetica', 'italic')
            doc.setFontSize(9)
            doc.setTextColor(90, 100, 115)
            const noteLines = doc.splitTextToSize(entry.notes, contentW)
            doc.text(noteLines, margin, y + 13)
            y += 13 * noteLines.length
          }

          doc.setDrawColor(220, 228, 240)
          doc.line(margin, y + 16, W - margin, y + 16)
          y += 28
        }

        addFooter()
      }

      // ── AI Insights page ────────────────────────────────────
      if (safeInsights.length > 0) {
        doc.addPage()
        doc.setFillColor(...BRAND)
        doc.rect(0, 0, W, 6, 'F')

        doc.setFontSize(14)
        doc.setTextColor(...BRAND)
        doc.setFont('helvetica', 'bold')
        doc.text('AI Insights', margin, 46)

        y = 72
        for (const insight of safeInsights) {
          if (y > H - 80) break
          doc.setFontSize(10)
          doc.setFont('helvetica', 'bold')
          doc.setTextColor(30, 40, 55)
          const predLines = doc.splitTextToSize(insight.prediction ?? '', contentW)
          doc.text(predLines, margin, y)
          y += 14 * predLines.length + 4

          if (Array.isArray(insight.suggestions)) {
            doc.setFont('helvetica', 'normal')
            doc.setFontSize(9)
            doc.setTextColor(70, 90, 115)
            for (const s of insight.suggestions.slice(0, 3)) {
              const sLines = doc.splitTextToSize(`• ${s}`, contentW - 12)
              doc.text(sLines, margin + 8, y)
              y += 13 * sLines.length
            }
          }

          y += 16
        }

        addFooter()
      }

      doc.save('echomirror-journal.pdf')
      showToast('PDF downloaded', 'success')
    } catch (err) {
      showToast(err instanceof Error ? err.message : 'PDF export failed', 'error')
    } finally {
      setExportLoading(false)
      setExportProgress(null)
    }
  }

  const handleSaveProfile = async () => {
    setProfileSaving(true)
    try {
      await upsertProfile(user.id, {
        display_name: displayName.trim() || null,
        timezone,
      })
      await supabase.auth.updateUser({ data: { timezone } })
      setProfile((prev) => ({ ...prev, display_name: displayName.trim() || null, timezone }))
      await queryClient.invalidateQueries({ queryKey: ['user-profile', user.id] })
      showToast('Profile updated successfully.', 'success')
    } catch (err) {
      showToast(err instanceof Error ? err.message : 'Failed to save profile.', 'error')
    } finally {
      setProfileSaving(false)
    }
  }

  const handleAvatarUpload = async (file: File) => {
    setAvatarUploading(true)
    try {
      const url = await uploadAvatar(user.id, file)
      await upsertProfile(user.id, { avatar_url: url })
      setProfile((prev) => ({ ...prev, avatar_url: url }))
      await queryClient.invalidateQueries({ queryKey: ['user-profile', user.id] })
      showToast('Avatar updated.', 'success')
    } catch (err) {
      showToast(err instanceof Error ? err.message : 'Avatar upload failed.', 'error')
    } finally {
      setAvatarUploading(false)
    }
  }

  const handleRemoveAvatar = async () => {
    try {
      await upsertProfile(user.id, { avatar_url: null })
      setProfile((prev) => ({ ...prev, avatar_url: null }))
      await queryClient.invalidateQueries({ queryKey: ['user-profile', user.id] })
      showToast('Avatar removed.', 'success')
    } catch (err) {
      showToast(err instanceof Error ? err.message : 'Failed to remove avatar.', 'error')
    }
  }

  const handleScheduleDeletion = async () => {
    if (deleteConfirmEmail.trim().toLowerCase() !== (user.email ?? '').toLowerCase()) {
      setDeleteError('Email does not match. Please type your account email to confirm.')
      return
    }
    setDeleteLoading(true)
    setDeleteError(null)
    try {
      const deletionDate = new Date()
      deletionDate.setDate(deletionDate.getDate() + GRACE_PERIOD_DAYS)

      const { error } = await supabase.auth.updateUser({
        data: { scheduled_deletion_at: deletionDate.toISOString() },
      })
      if (error) throw error

      setScheduledDeletionAt(deletionDate)
      setShowDeleteConfirm(false)
      setDeleteConfirmEmail('')
      showToast(`Account scheduled for deletion on ${deletionDate.toLocaleDateString()}.`, 'success')
    } catch (err) {
      showToast(err instanceof Error ? err.message : 'Scheduling deletion failed.', 'error')
    } finally {
      setDeleteLoading(false)
    }
  }

  const handleCancelDeletion = async () => {
    setCancelDeletionLoading(true)
    try {
      const { error } = await supabase.auth.updateUser({
        data: { scheduled_deletion_at: null },
      })
      if (error) throw error
      setScheduledDeletionAt(null)
      showToast('Account deletion cancelled.', 'success')
    } catch (err) {
      showToast(err instanceof Error ? err.message : 'Failed to cancel deletion.', 'error')
    } finally {
      setCancelDeletionLoading(false)
    }
  }

  // ── Render ───────────────────────────────────────────────────────────────────

  return (
    <section className="feature-grid">
      {/* Grace period banner */}
      {scheduledDeletionAt && (
        <div
          role="alert"
          style={{
            gridColumn: '1 / -1',
            padding: '0.75rem 1rem',
            borderRadius: '10px',
            background: 'color-mix(in srgb, var(--danger) 12%, transparent)',
            border: '1px solid color-mix(in srgb, var(--danger) 30%, transparent)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: '1rem',
            flexWrap: 'wrap',
          }}
        >
          <p style={{ margin: 0, fontSize: '0.9rem', color: 'var(--danger)' }}>
            Your account is scheduled for deletion on{' '}
            <strong>{scheduledDeletionAt.toLocaleDateString(undefined, { dateStyle: 'long' })}</strong>.
          </p>
          <button
            type="button"
            onClick={() => void handleCancelDeletion()}
            disabled={cancelDeletionLoading}
            style={{
              padding: '0.35rem 0.8rem',
              borderRadius: '8px',
              border: '1px solid var(--danger)',
              background: 'transparent',
              color: 'var(--danger)',
              cursor: 'pointer',
              fontSize: '0.85rem',
              flexShrink: 0,
            }}
          >
            {cancelDeletionLoading ? 'Cancelling…' : 'Cancel deletion'}
          </button>
        </div>
      )}

      {/* ── Profile Section ── */}
      <article className="card">
        <div className="card-header">
          <h3>Profile</h3>
        </div>
        <div className="card-content form-stack">
          {profileLoading ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.6rem' }}>
              {[80, 16, 16].map((h, i) => (
                <div
                  key={i}
                  style={{
                    height: h,
                    borderRadius: h === 80 ? '50%' : 6,
                    width: h === 80 ? 80 : '100%',
                    background: 'var(--surface-soft)',
                    animation: 'skeleton-shimmer 1.4s ease-in-out infinite',
                  }}
                  aria-hidden="true"
                />
              ))}
            </div>
          ) : (
            <>
              <AvatarUpload
                avatarUrl={profile.avatar_url}
                displayName={profile.display_name}
                onConfirmUpload={(file) => void handleAvatarUpload(file)}
                onRemove={() => void handleRemoveAvatar()}
                uploading={avatarUploading}
              />

              <label>
                Email
                <input type="email" value={user.email ?? ''} readOnly disabled aria-readonly="true" />
              </label>

              <label>
                Display name
                <input
                  type="text"
                  value={displayName}
                  onChange={(e) => setDisplayName(e.target.value)}
                  placeholder="Your name"
                  maxLength={60}
                />
              </label>

              <label>
                Timezone
                <TimezoneCombobox value={timezone} onChange={setTimezone} />
              </label>

              <button
                type="button"
                onClick={() => void handleSaveProfile()}
                disabled={profileSaving}
              >
                {profileSaving ? 'Saving…' : 'Save profile'}
              </button>
            </>
          )}
        </div>
      </article>

      {/* ── Theme Section ── */}
      <article className="card">
        <div className="card-header">
          <h3>Theme</h3>
        </div>
        <div className="card-content">
          <div className="chip-row">
            {(['light', 'system', 'dark'] as const).map((t) => (
              <button
                key={t}
                type="button"
                className={theme === t ? 'chip active' : 'chip'}
                onClick={() => setTheme(t)}
                aria-pressed={theme === t}
              >
                {t.charAt(0).toUpperCase() + t.slice(1)}
              </button>
            ))}
          </div>
        </div>
      </article>

      {/* ── Leaderboard Privacy Section ── */}
      <article className="card">
        <div className="card-header">
          <h3>🏆 Leaderboard</h3>
        </div>
        <div className="card-content">
          <div className="flex items-center justify-between" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <p className="font-medium text-gray-900 dark:text-gray-100" style={{ fontWeight: 500, margin: 0 }}>Show me on leaderboard</p>
              <p className="text-sm text-gray-500" style={{ fontSize: '0.875rem', color: 'var(--muted)', margin: '4px 0 0 0' }}>Display your name on the weekly leaderboard</p>
            </div>
            <label className="relative inline-flex items-center cursor-pointer" style={{ position: 'relative', display: 'inline-flex', alignItems: 'center', cursor: 'pointer' }}>
              <input
                type="checkbox"
                checked={!profile.leaderboard_anonymous}
                onChange={async (e) => {
                  const isAnonymous = !e.target.checked;
                  try {
                    const { error } = await supabase
                      .from('profiles')
                      .update({ leaderboard_anonymous: isAnonymous })
                      .eq('id', user.id);
                    if (error) throw error;
                    setProfile((prev) => ({ ...prev, leaderboard_anonymous: isAnonymous }));
                    showToast('Leaderboard visibility updated', 'success');
                  } catch (err) {
                    showToast('Failed to update leaderboard visibility', 'error');
                  }
                }}
                className="sr-only peer"
                style={{ position: 'absolute', width: '1px', height: '1px', padding: 0, margin: '-1px', overflow: 'hidden', clip: 'rect(0,0,0,0)', border: 0 }}
              />
              <div className="w-11 h-6 bg-gray-200 peer-focus:ring-4 peer-focus:ring-indigo-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-indigo-600" style={{ width: '2.75rem', height: '1.5rem', background: profile.leaderboard_anonymous ? 'var(--line)' : 'var(--brand)', borderRadius: '9999px', transition: 'background 0.2s' }}></div>
            </label>
          </div>
        </div>
      </article>

      {/* ── Data Export Section ── */}
      <article className="card">
        <div className="card-header">
          <h3>Data export</h3>
        </div>
        <div className="card-content">
          <p className="muted">Download all your data as a file</p>
          <div className="chip-row" style={{ marginBottom: '0.6rem' }}>
            {(['json', 'csv'] as const).map((fmt) => (
              <button
                key={fmt}
                type="button"
                className={exportFormat === fmt ? 'chip active' : 'chip'}
                onClick={() => setExportFormat(fmt)}
                disabled={exportLoading}
              >
                {fmt.toUpperCase()}
              </button>
            ))}
          </div>
          <div style={{ display: 'flex', gap: '0.6rem', flexWrap: 'wrap' }}>
            <button type="button" onClick={() => void handleExport()} disabled={exportLoading}>
              {exportLoading ? exportProgress ?? 'Exporting…' : 'Export my data'}
            </button>
            <button
              type="button"
              onClick={() => void handleExportPDF()}
              disabled={exportLoading}
              style={{ background: 'transparent', color: 'var(--brand)', border: '1.5px solid var(--brand)' }}
            >
              {exportLoading ? exportProgress ?? 'Building PDF…' : 'Export as PDF'}
            </button>
          </div>
          {exportError && <p className="error-text">{exportError}</p>}
        </div>
      </article>

      {/* ── Password Section ── */}
      <PasswordChangeSection />

      {/* ── Notifications ── */}
      <NotificationPrefs userId={user.id} />

      {/* ── Danger Zone ── */}
      <article className="card danger-zone">
        <div className="card-header">
          <h3>Danger zone</h3>
        </div>
        <div className="card-content">
          {scheduledDeletionAt ? (
            <p className="muted">
              Account deletion is already scheduled.
              Use the banner above to cancel.
            </p>
          ) : (
            <>
              <p className="muted">
                Request account deletion. You will have a {GRACE_PERIOD_DAYS}-day window to cancel before all
                data is permanently removed.
              </p>

              {!showDeleteConfirm ? (
                <button
                  type="button"
                  className="danger"
                  onClick={() => setShowDeleteConfirm(true)}
                >
                  Delete account
                </button>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '0.6rem', marginTop: '0.5rem' }}>
                  <p style={{ fontSize: '0.85rem', color: 'var(--danger)', margin: 0 }}>
                    Type your email <strong>{user.email}</strong> to schedule deletion:
                  </p>
                  <input
                    type="email"
                    value={deleteConfirmEmail}
                    onChange={(e) => setDeleteConfirmEmail(e.target.value)}
                    placeholder={user.email ?? 'your@email.com'}
                    autoComplete="off"
                    aria-label="Confirm account email for deletion"
                  />
                  {deleteError && <p role="alert" className="error-text">{deleteError}</p>}
                  <div style={{ display: 'flex', gap: '0.5rem' }}>
                    <button
                      type="button"
                      className="danger"
                      onClick={() => void handleScheduleDeletion()}
                      disabled={deleteLoading}
                    >
                      {deleteLoading ? 'Scheduling…' : 'Schedule deletion'}
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        setShowDeleteConfirm(false)
                        setDeleteConfirmEmail('')
                        setDeleteError(null)
                      }}
                    >
                      Cancel
                    </button>
                  </div>
                </div>
              )}
            </>
          )}
        </div>
      </article>

      <style>{`
        @keyframes skeleton-shimmer {
          0%, 100% { opacity: 1; }
          50%       { opacity: 0.4; }
        }
      `}</style>
    </section>
  )
} 
