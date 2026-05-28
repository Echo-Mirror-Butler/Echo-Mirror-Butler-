import { useEffect, useMemo, useState, useRef, useId } from 'react'
import { NavLink, Outlet, useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { useAuth } from '../../lib/auth-context'
import { supabase } from '../../lib/supabase'
import { useSearchLogs } from '../../lib/use-search-logs'
import { useTheme } from '../../lib/use-theme'
import { formatDate, moodToEmoji } from '../../lib/date'
import { NotificationDrawer } from '../../features/notifications/notification-drawer'

type UserProfile = { display_name: string | null; avatar_url: string | null }

async function fetchUserProfile(userId: string): Promise<UserProfile> {
  const { data } = await supabase
    .from('profiles')
    .select('display_name, avatar_url')
    .eq('id', userId)
    .single()
  if (!data) return { display_name: null, avatar_url: null }
  const row = data as Record<string, unknown>
  return {
    display_name: (row.display_name as string | null) ?? null,
    avatar_url: (row.avatar_url as string | null) ?? null,
  }
}

const navItems = [
  { icon: '🏠', to: '/dashboard', label: 'Dashboard' },
  { icon: '📝', to: '/logs', label: 'Logs' },
  { icon: '✨', to: '/insights', label: 'AI Insights' },
  { icon: '📊', to: '/analytics', label: 'Analytics' },
  { icon: '🌍', to: '/global-mirror', label: 'Global Mirror' },
  { icon: '💎', to: '/wallet', label: 'Wallet' },
  { icon: '⚙️', to: '/settings', label: 'Settings' },
]

async function getUnreadNotificationsCount(userId: string): Promise<number> {
  const { count, error } = await supabase
    .from('mood_comment_notifications')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId)
    .eq('is_read', false)

  if (error) {
    return 0
  }

  return count ?? 0
}

export function AppShell() {
  const navigate = useNavigate()
  const { user, signOut } = useAuth()
  const [isCollapsed, setIsCollapsed] = useState(false)
  const [isMobileDrawerOpen, setIsMobileDrawerOpen] = useState(false)
  const [isUserMenuOpen, setIsUserMenuOpen] = useState(false)
  const [isNotificationPanelOpen, setIsNotificationPanelOpen] = useState(false)
  const { resolvedTheme, setTheme } = useTheme()

  // Search state
  const [searchQuery, setSearchQuery] = useState('')
  const [isSearchOpen, setIsSearchOpen] = useState(false)
  const [selectedResultIdx, setSelectedResultIdx] = useState(-1)
  const searchInputRef = useRef<HTMLInputElement>(null)
  const { results: searchResults, isLoading: searchLoading } = useSearchLogs(user?.id, searchQuery)
  const searchListboxId = useId()

  const unreadNotificationsQuery = useQuery({
    queryKey: ['unread-notifications', user?.id],
    queryFn: () => getUnreadNotificationsCount(user!.id),
    enabled: Boolean(user?.id),
    refetchInterval: 30_000,
  })

  const profileQuery = useQuery({
    queryKey: ['user-profile', user?.id],
    queryFn: () => fetchUserProfile(user!.id),
    enabled: Boolean(user?.id),
    staleTime: 5 * 60 * 1000,
  })

  const avatarText = useMemo(() => {
    const name = profileQuery.data?.display_name ?? user?.email ?? ''
    return name.trim().charAt(0).toUpperCase() || 'U'
  }, [profileQuery.data?.display_name, user?.email])

  useEffect(() => {
    if (!isMobileDrawerOpen) {
      return
    }

    const onEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setIsMobileDrawerOpen(false)
      }
    }

    window.addEventListener('keydown', onEscape)
    return () => window.removeEventListener('keydown', onEscape)
  }, [isMobileDrawerOpen])

  // Handle keyboard navigation in search
  useEffect(() => {
    const handleSearchKeyDown = (event: KeyboardEvent) => {
      if (!isSearchOpen || searchResults.length === 0) {
        if (event.key === 'Escape') {
          setIsSearchOpen(false)
        }
        return
      }

      if (event.key === 'ArrowDown') {
        event.preventDefault()
        setSelectedResultIdx((prev) => (prev + 1) % searchResults.length)
      } else if (event.key === 'ArrowUp') {
        event.preventDefault()
        setSelectedResultIdx((prev) => (prev - 1 + searchResults.length) % searchResults.length)
      } else if (event.key === 'Enter' && selectedResultIdx >= 0) {
        event.preventDefault()
        const result = searchResults[selectedResultIdx]
        navigate(`/logs/${result.id}/edit`)
        setSearchQuery('')
        setIsSearchOpen(false)
        setSelectedResultIdx(-1)
      } else if (event.key === 'Escape') {
        setIsSearchOpen(false)
        setSelectedResultIdx(-1)
      }
    }

    if (searchInputRef.current === document.activeElement) {
      document.addEventListener('keydown', handleSearchKeyDown)
      return () => document.removeEventListener('keydown', handleSearchKeyDown)
    }
  }, [isSearchOpen, selectedResultIdx, searchResults, navigate])

  const onSignOut = async () => {
    await signOut()
    navigate('/login', { replace: true })
  }

  return (
    <div className="shell-root">
      <aside
        className={[
          'shell-sidebar',
          isCollapsed ? 'collapsed' : '',
          isMobileDrawerOpen ? 'open' : '',
        ]
          .filter(Boolean)
          .join(' ')}
      >
        <div className="shell-sidebar-header">
          <h1>EchoMirror</h1>
          <button
            type="button"
            className="icon-btn desktop-only"
            aria-label={isCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}
            onClick={() => setIsCollapsed((prev) => !prev)}
          >
            {isCollapsed ? '⟩' : '⟨'}
          </button>
        </div>

        <nav className="shell-nav">
          {navItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                ['shell-nav-item', isActive ? 'active' : ''].filter(Boolean).join(' ')
              }
              onClick={() => setIsMobileDrawerOpen(false)}
            >
              <span className="icon">{item.icon}</span>
              <span className="label">{item.label}</span>
            </NavLink>
          ))}
        </nav>

        <div className="shell-sidebar-footer">
          <span className="email-text">{user?.email ?? 'Signed in user'}</span>
        </div>
      </aside>

      {isMobileDrawerOpen ? (
        <button
          className="shell-drawer-overlay"
          type="button"
          aria-label="Close navigation drawer"
          onClick={() => setIsMobileDrawerOpen(false)}
        />
      ) : null}

      <section className="shell-main">
        <header className="shell-topbar">
          <div className="shell-topbar-left">
            <button
              type="button"
              className="icon-btn mobile-only"
              aria-label="Open navigation drawer"
              onClick={() => setIsMobileDrawerOpen(true)}
            >
              ☰
            </button>
            <span className="shell-logo-text">EchoMirror</span>
          </div>

          <div className="shell-search" style={{ position: 'relative' }}>
            <div style={{ position: 'relative', width: '100%' }}>
              <span
                style={{
                  position: 'absolute',
                  left: '0.65rem',
                  top: '50%',
                  transform: 'translateY(-50%)',
                  fontSize: '0.85rem',
                  color: 'var(--muted)',
                  pointerEvents: 'none',
                }}
                aria-hidden="true"
              >
                🔍
              </span>
              <input
                ref={searchInputRef}
                id="search-logs-input"
                type="text"
                role="combobox"
                aria-expanded={isSearchOpen && searchResults.length > 0}
                aria-controls={searchListboxId}
                aria-activedescendant={selectedResultIdx >= 0 ? `search-result-${selectedResultIdx}` : undefined}
                aria-autocomplete="list"
                aria-haspopup="listbox"
                aria-label="Search logs by notes, date, or mood score"
                placeholder="Search logs…"
                value={searchQuery}
                style={{ paddingLeft: '2rem' }}
                onChange={(e) => {
                  setSearchQuery(e.target.value)
                  setIsSearchOpen(true)
                  setSelectedResultIdx(-1)
                }}
                onFocus={() => searchQuery && setIsSearchOpen(true)}
                autoComplete="off"
              />
            </div>
            {isSearchOpen && (
              <div
                id={searchListboxId}
                role="listbox"
                className="search-dropdown"
                style={{
                  position: 'absolute',
                  top: '100%',
                  left: 0,
                  right: 0,
                  zIndex: 1000,
                }}
              >
                {searchLoading ? (
                  <div className="search-empty">Searching…</div>
                ) : searchResults.length === 0 && searchQuery ? (
                  <div className="search-empty">No logs matched</div>
                ) : (
                  <div className="search-results">
                    {searchResults.map((result, idx) => (
                      <button
                        key={result.id}
                        id={`search-result-${idx}`}
                        role="option"
                        type="button"
                        aria-selected={selectedResultIdx === idx}
                        className={`search-result ${selectedResultIdx === idx ? 'focused' : ''}`}
                        onClick={() => {
                          navigate(`/logs/${result.id}/edit`)
                          setSearchQuery('')
                          setIsSearchOpen(false)
                          setSelectedResultIdx(-1)
                        }}
                      >
                        <span className="result-date">{formatDate(result.date)}</span>
                        <span className="result-mood">{moodToEmoji(result.mood)}</span>
                        <span className="result-notes">{result.notes ? result.notes.substring(0, 60) : 'No notes'}</span>
                      </button>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>
          {isSearchOpen && (
            <button
              type="button"
              className="search-overlay"
              onClick={() => {
                setIsSearchOpen(false)
                setSelectedResultIdx(-1)
              }}
              style={{
                position: 'fixed',
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                zIndex: 999,
              }}
              aria-hidden="true"
            />
          )}

          <div className="shell-topbar-actions">
            <button
              type="button"
              className="icon-btn"
              aria-label={resolvedTheme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'}
              onClick={() => setTheme(resolvedTheme === 'dark' ? 'light' : 'dark')}
            >
              {resolvedTheme === 'dark' ? '☀️' : '🌙'}
            </button>

            <div style={{ position: 'relative' }}>
              <button
                type="button"
                className="icon-btn notification-btn"
                aria-label="Notifications"
                aria-expanded={isNotificationPanelOpen}
                onClick={() => setIsNotificationPanelOpen((prev) => !prev)}
              >
                🔔
                {(unreadNotificationsQuery.data ?? 0) > 0 ? (
                  <span className="badge">{unreadNotificationsQuery.data}</span>
                ) : null}
              </button>
              <NotificationDrawer
                isOpen={isNotificationPanelOpen}
                onClose={() => setIsNotificationPanelOpen(false)}
              />
            </div>

            <div className="avatar-menu-wrap">
              <button
                type="button"
                className="avatar-btn"
                onClick={() => setIsUserMenuOpen((prev) => !prev)}
                aria-expanded={isUserMenuOpen}
                aria-label="User menu"
              >
                {profileQuery.data?.avatar_url ? (
                  <img
                    src={profileQuery.data.avatar_url}
                    alt={profileQuery.data.display_name ?? user?.email ?? 'Avatar'}
                    style={{ width: '100%', height: '100%', objectFit: 'cover', borderRadius: '50%' }}
                  />
                ) : (
                  <span>{avatarText}</span>
                )}
              </button>

              {isUserMenuOpen ? (
                <div className="avatar-menu">
                  <button type="button" onClick={() => navigate('/settings')}>
                    Profile
                  </button>
                  <button type="button" onClick={() => void onSignOut()}>
                    Sign out
                  </button>
                </div>
              ) : null}
            </div>
          </div>
        </header>

        <main className="shell-content animate-stagger">
          <Outlet />
        </main>
      </section>
    </div>
  )
}
