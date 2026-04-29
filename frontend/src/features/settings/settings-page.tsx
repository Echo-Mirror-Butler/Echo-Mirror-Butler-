import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../../lib/auth-context'
import { useTheme } from '../../lib/use-theme'
import { supabase } from '../../lib/supabase'

export function SettingsPage() {
  const navigate = useNavigate()
  const { user, signOut } = useAuth()
  const { theme, setTheme } = useTheme()

  const [newPassword, setNewPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [passwordError, setPasswordError] = useState<string | null>(null)
  const [passwordSuccess, setPasswordSuccess] = useState<string | null>(null)
  const [passwordLoading, setPasswordLoading] = useState(false)

  const [deleteLoading, setDeleteLoading] = useState(false)

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
