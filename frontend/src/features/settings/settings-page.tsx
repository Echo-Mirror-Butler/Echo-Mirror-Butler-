/**
 * Settings Page (#304)
 *
 * - Avatar upload using Supabase Storage (avatars bucket)
 * - Display name field — saved to profiles.display_name
 * - Timezone selector using Intl.supportedValuesOf('timeZone') — saved to user_metadata.timezone
 * - Avatar shown in topbar via profile context (AppShell reads from profiles table)
 * - Danger zone: Delete account (requires re-auth confirmation)
 * - Toast notifications for success/error feedback
 */
import { useEffect, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import { useAuth } from '../../lib/auth-context'
import { useTheme } from '../../lib/use-theme'
import { useToast } from '../../lib/use-toast'
import { supabase } from '../../lib/supabase'
import { NotificationPrefs } from '../notifications/notification-prefs'

// ── Types ─────────────────────────────────────────────────────────────────────

type Profile = {
  display_name: string | null
  avatar_url: string | null
  timezone: string
}

// ── Constants ─────────────────────────────────────────────────="────────────────

const MAX_AVATAR_SIZE_BYTES = 2 * 1024 * 1024 // 2 MB
const ALLOWED_AVATAR_TYPES = ['image/png', 'image/jpeg', 'image/jpg']
const AVATAR_BUCKET = 'avatars'

// Get all IANA timezones supported by the browser
function getSupportedTimezones(): string[] {
  try {
    // @ts-expect-error — Intl.supportedValuesOf is available in modern browsers
    return (Intl.supportedValuesOf('timeZone') as string[]).sort()
  } catch {
    // Fallback list for older browsers
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

const TIMEZONES = getSupportedTimezones()

// ── Helpers ───────────────────────────────────────────────────────────────────

async function fetchProfile(userId: string): Promise<Profile> {
  const { data, error } = await supabase
    .from('profiles')
    .select('display_name, avatar_url, timezone')
    .eq('id', userId)
    .single()

  if (error || !data) {
    return { display_name: null, avatar_url: null, timezone: 'UTC' }
  }

  return {
    display_name: (data as Record<string, unknown>).display_name as string | null,
    avatar_url: (data as Record<string, unknown>).avatar_url as string | null,
    timezone: ((data as Record<string, unknown>).timezone as string) ?? 'UTC',
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
  // Bust cache with timestamp
  return `${data.publicUrl}?t=${Date.now()}`
}

// ── Sub-components ────────────────────────────────────────────────────────────

function AvatarUpload({
  avatarUrl,
  displayName,
  onUpload,
}: {
  avatarUrl: string | null
  displayName: string | null
  onUpload: (file: File) => void
}) {
  const inputRef = useRef<HTMLInputElement>(null)
  const [dragOver, setDragOver] = useState(false)
  const [fileError, setFileError] = useState<string | null>(null)

  const initials = displayName
    ? displayName.trim().split(' ').map((w) => w[0]).join('').toUpperCase().slice(0, 2)
    : 'U'

  function validateAndUpload(file: File) {
    setFileError(null)
    if (!ALLOWED_AVATAR_TYPES.includes(file.type)) {
      setFileError('Only PNG or JPG files are allowed.')
      return
    }
    if (file.size > MAX_AVATAR_SIZE_BYTES) {
      setFileError('File must be under 2 MB.')
      return
    }
    onUpload(file)
  }

  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: '1.25rem', flexWrap: 'wrap' }}>
      {/* Avatar preview */}
      <div
        style={{
          width: 72,
          height: 72,
          borderRadius: '50%',
          overflow: 'hidden',
          background: 'var(--brand)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexShrink: 0,
          border: '2px solid var(--line)',
        }}
      >
        {avatarUrl ? (
          <img
            src={avatarUrl}
            alt={displayName ?? 'Avatar'}
            style={{ width: '100%', height: '100%', objectFit: 'cover' }}
          />
        ) : (
          <span style={{ color: '#fff', fontWeight: 700, fontSize: '1.4rem' }}>{initials}</span>
        )}
      </div>

      {/* Upload controls */}
      <div>
        <button
          type="button"
          onClick={() => inputRef.current?.click()}
          onDragOver={(e) => { e.preventDefault(); setDragOver(true) }}
          onDragLeave={() => setDragOver(false)}
          onDrop={(e) => {
            e.preventDefault()
            setDragOver(false)
            const file = e.dataTransfer.files[0]
            if (file) validateAndUpload(file)
          }}
          style={{
            padding: '0.4rem 0.9rem',
            borderRadius: '8px',
            border: `1px dashed ${dragOver ? 'var(--brand)' : 'var(--line)'}`,
            background: dragOver ? 'var(--brand-soft)' : 'transparent',
            cursor: 'pointer',
            fontSize: '0.85rem',
            color: 'var(--text)',
          }}
        >
          📷 Upload photo
        </button>
        <p className="muted" style={{ margin: '0.3rem 0 0', fontSize: '0.75rem' }}>
          PNG or JPG, max 2 MB
        </p>
        {fileError && (
          <p role="alert" style={{ color: 'var(--danger)', fontSize: '0.78rem', margin: '0.25rem 0 0' }}>
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
            if (file) validateAndUpload(file)
            e.target.value = ''
          }}
        />
      </div>
    </div>
  )
}

// ── Page ──────────────────────────────────────────────────────────────────────

type ExportFormat = 'json' | 'csv'

export function SettingsPage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { user, session, signOut } = useAuth()
  const { theme, setTheme } = useTheme()

  // Profile state
  const [profile, setProfile] = useState<Profile>({ display_name: null, avatar_url: null, timezone: 'UTC' })
  const [profileLoading, setProfileLoading] = useState(true)
  const [displayName, setDisplayName] = useState('')
  const [timezone, setTimezone] = useState('UTC')
  const [profileSaving, setProfileSaving] = useState(false)
  const [avatarUploading, setAvatarUploading] = useState(false)

  const { showToast } = useToast()

  // Delete state
  const [deleteLoading, setDeleteLoading] = useState(false)
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)
  const [deleteConfirmEmail, setDeleteConfirmEmail] = useState('')
  const [deleteError, setDeleteError] = useState<string | null>(null)

  const [exportFormat, setExportFormat] = useState<ExportFormat>('json')
  const [exportLoading, setExportLoading] = useState(false)
  const [exportError, setExportError] = useState<string | null>(null)
  const [exportSuccess, setExportSuccess] = useState<string | null>(null)

  // Load profile on mount
  useEffect(() => {
    if (!user?.id) return
    setProfileLoading(true)
    fetchProfile(user.id).then((p) => {
      setProfile(p)
      setDisplayName(p.display_name ?? '')
      setTimezone(p.timezone ?? 'UTC')
      setProfileLoading(false)
    })
  }, [user?.id])

  if (!user) return null

  // ── Handlers ────────────────────────────────────────────────────────────────

  const handleExport = async () => {
    setExportError(null)
    setExportSuccess(null)
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

      const blob = await res.blob()
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = res.headers.get('content-disposition')?.match(/filename="(.+)"/)?.[1]
        ?? `echomirror-export.${exportFormat}`
      document.body.appendChild(a)
      a.click()
      a.remove()
      URL.revokeObjectURL(url)
      showToast('Export downloaded', 'success')
    } catch (err) {
      showToast(err instanceof Error ? err.message : 'Export failed', 'error')
    } finally {
      setExportLoading(false)
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

  const handleDeleteAccount = async () => {
    if (deleteConfirmEmail.trim().toLowerCase() !== (user.email ?? '').toLowerCase()) {
      setDeleteError('Email does not match. Please type your account email to confirm.')
      return
    }
    setDeleteLoading(true)
    setDeleteError(null)
    try {
      const { error } = await supabase.rpc('delete_user')
      if (error) throw error
      showToast('Account deleted. Goodbye!', 'success')
      await signOut()
      navigate('/login')
    } catch (err) {
      showToast(err instanceof Error ? err.message : 'Account deletion failed.', 'error')
    } finally {
      setDeleteLoading(false)
    }
  }

  // ── Render ───────────────────────────────────────────────────────────────────

  return (
    <section className="feature-grid">
      {/* ── Profile Section ── */}
      <article className="card">
        <div className="card-header">
          <h3>Profile</h3>
        </div>
        <div className="card-content form-stack">
          {profileLoading ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.6rem' }}>
              {[72, 16, 16].map((h, i) => (
                <div
                  key={i}
                  style={{
                    height: h,
                    borderRadius: h === 72 ? '50%' : 6,
                    width: h === 72 ? 72 : '100%',
                    background: 'var(--surface-soft)',
                    animation: 'skeleton-shimmer 1.4s ease-in-out infinite',
                  }}
                  aria-hidden="true"
                />
              ))}
            </div>
          ) : (
            <>
              {/* Avatar */}
              <AvatarUpload
                avatarUrl={profile.avatar_url}
                displayName={profile.display_name}
                onUpload={handleAvatarUpload}
              />
              {avatarUploading && (
                <p className="muted" style={{ fontSize: '0.82rem' }}>Uploading avatar…</p>
              )}

              {/* Email (read-only) */}
              <label>
                Email
                <input type="email" value={user.email ?? ''} readOnly disabled aria-readonly="true" />
              </label>

              {/* Display name */}
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

              {/* Timezone */}
              <label>
                Timezone
                <select
                  value={timezone}
                  onChange={(e) => setTimezone(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '0.45rem 0.65rem',
                    borderRadius: '8px',
                    border: '1px solid var(--line)',
                    background: 'var(--surface)',
                    color: 'var(--text)',
                    fontSize: '0.9rem',
                  }}
                >
                  {TIMEZONES.map((tz) => (
                    <option key={tz} value={tz}>{tz}</option>
                  ))}
                </select>
              </label>

              <button
                type="button"
                onClick={handleSaveProfile}
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
              >
                {fmt.toUpperCase()}
              </button>
            ))}
          </div>
          <button type="button" onClick={handleExport} disabled={exportLoading}>
            {exportLoading ? 'Exporting…' : 'Export my data'}
          </button>
          {exportError && <p className="error-text">{exportError}</p>}
          {exportSuccess && <p className="success-text">{exportSuccess}</p>}
        </div>
      </article>

      {/* ── Password Section ── */}
      <article className="card">
        <div className="card-header">
          <h3>Change password</h3>
        </div>
        <div className="card-content">
          <p className="muted">Update your account password on the dedicated page.</p>
          <button type="button" onClick={() => navigate('/update-password')}>
            Go to password page
          </button>
        </div>
      </article>

      {/* ── Notifications (push) — Issue #303 ── */}
      <NotificationPrefs userId={user.id} />

      {/* ── Danger Zone ── */}
      <article className="card danger-zone">
        <div className="card-header">
          <h3>Danger zone</h3>
        </div>
        <div className="card-content">
          <p className="muted">Permanently delete your account and all associated data. This cannot be undone.</p>

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
                Type your email <strong>{user.email}</strong> to confirm deletion:
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
                  onClick={() => void handleDeleteAccount()}
                  disabled={deleteLoading}
                >
                  {deleteLoading ? 'Deleting…' : 'Confirm delete'}
                </button>
                <button
                  type="button"
                  onClick={() => { setShowDeleteConfirm(false); setDeleteConfirmEmail(''); setDeleteError(null) }}
                >
                  Cancel
                </button>
              </div>
            </div>
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
