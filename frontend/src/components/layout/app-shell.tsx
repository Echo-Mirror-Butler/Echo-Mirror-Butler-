import { useEffect, useMemo, useState } from 'react'
import { NavLink, Outlet, useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { useAuth } from '../../lib/auth-context'
import { supabase } from '../../lib/supabase'
import { NotificationDrawer } from '../../features/notifications/notification-drawer'

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

  const unreadNotificationsQuery = useQuery({
    queryKey: ['unread-notifications', user?.id],
    queryFn: () => getUnreadNotificationsCount(user!.id),
    enabled: Boolean(user?.id),
    refetchInterval: 30_000,
  })

  const avatarText = useMemo(() => {
    const email = user?.email ?? ''
    return email.trim().charAt(0).toUpperCase() || 'U'
  }, [user?.email])

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

          <label className="shell-search">
            <span className="sr-only">Search</span>
            <input type="text" placeholder="Search (coming soon)" />
          </label>

          <div className="shell-topbar-actions">
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
              >
                <span>{avatarText}</span>
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
