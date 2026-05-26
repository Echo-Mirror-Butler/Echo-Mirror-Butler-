import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../../lib/auth-context'
import { useTheme } from '../../lib/use-theme'
import { supabase } from '../../lib/supabase'

type ExportFormat = 'json' | 'csv'

export function SettingsPage() {
  const navigate = useNavigate()
  const { user, session, signOut } = useAuth()
  const { theme, setTheme } = useTheme()

  const [newPassword, setNewPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [passwordError, setPasswordError] = useState<string | null>(null)
  const [passwordSuccess, setPasswordSuccess] = useState<string | null>(null)
  const [passwordLoading, setPasswordLoading] = useState(false)

  const [deleteLoading, setDeleteLoading] = useState(false)

  const [exportFormat, setExportFormat] = useState<ExportFormat>('json')
  const [exportLoading, setExportLoading] = useState(false)
  const [exportError, setExportError] = useState<string | null>(null)
  const [exportSuccess, setExportSuccess] = useState<string | null>(null)

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
      setExportSuccess('Export downloaded successfully')
    } catch (err) {
      setExportError(err instanceof Error ? err.message : 'Export failed')
    } finally {
      setExportLoading(false)
    }
  }

  if (!user) {
    return null
  }

  const handlePasswordChange = async () => {
    setPasswordError(null)
    setPasswordSuccess(null)

    if (!newPassword.trim()) {
      setPasswordError('Password is required')
      return
    }

    if (newPassword !== confirmPassword) {
      setPasswordError('Passwords do not match')
      return
    }

    if (newPassword.length < 6) {
      setPasswordError('Password must be at least 6 characters')
      return
    }

    setPasswordLoading(true)
    try {
      const { error } = await supabase.auth.updateUser({ password: newPassword })
      if (error) {
        setPasswordError(error.message)
      } else {
        setPasswordSuccess('Password updated successfully')
        setNewPassword('')
        setConfirmPassword('')
      }
    } catch (err) {
      setPasswordError(err instanceof Error ? err.message : 'Password update failed')
    } finally {
      setPasswordLoading(false)
    }
  }

  const handleDeleteAccount = async () => {
    const shouldDelete = window.confirm(
      'Delete your account? This will permanently remove all your data and cannot be undone.'
    )
    if (!shouldDelete) {
      return
    }

    setDeleteLoading(true)
    try {
      const { error } = await supabase.rpc('delete_user')
      if (error) {
        console.error('Delete error:', error)
      }
      await signOut()
      navigate('/login')
    } catch (err) {
      console.error('Delete failed:', err)
    } finally {
      setDeleteLoading(false)
    }
  }

  return (
    <section className="feature-grid">
      {/* Profile Section */}
      <article className="card">
        <div className="card-header">
          <h3>Profile</h3>
        </div>
        <div className="card-content">
          <p className="muted">Email</p>
          <p>{user.email}</p>
        </div>
      </article>

      {/* Theme Section */}
      <article className="card">
        <div className="card-header">
          <h3>Theme</h3>
        </div>
        <div className="card-content">
          <div className="chip-row">
            {['light', 'system', 'dark'].map((t) => (
              <button
                key={t}
                type="button"
                className={theme === t ? 'chip active' : 'chip'}
                onClick={() => setTheme(t as 'light' | 'dark' | 'system')}
              >
                {t.charAt(0).toUpperCase() + t.slice(1)}
              </button>
            ))}
          </div>
        </div>
      </article>

      {/* Data Export Section */}
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

      {/* Password Section */}
      <article className="card">
        <div className="card-header">
          <h3>Change password</h3>
        </div>
        <form
          className="card-content form-stack"
          onSubmit={(e) => {
            e.preventDefault()
            handlePasswordChange()
          }}
        >
          <label>
            New password
            <input
              type="password"
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              placeholder="Enter new password"
            />
          </label>
          <label>
            Confirm password
            <input
              type="password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              placeholder="Confirm password"
            />
          </label>
          <button type="submit" disabled={passwordLoading}>
            {passwordLoading ? 'Updating…' : 'Update password'}
          </button>
          {passwordError && <p className="error-text">{passwordError}</p>}
          {passwordSuccess && <p className="success-text">{passwordSuccess}</p>}
        </form>
      </article>

      {/* Danger Zone */}
      <article className="card danger-zone">
        <div className="card-header">
          <h3>Danger zone</h3>
        </div>
        <div className="card-content">
          <p className="muted">Delete your account and all associated data</p>
          <button
            type="button"
            className="danger"
            onClick={handleDeleteAccount}
            disabled={deleteLoading}
          >
            {deleteLoading ? 'Deleting…' : 'Delete account'}
          </button>
        </div>
      </article>
    </section>
  )
}
