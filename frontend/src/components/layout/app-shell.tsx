import { Link, NavLink, Outlet } from 'react-router-dom'
import { useAuth } from '../../lib/auth-context'

const navItems = [
  { to: '/dashboard', label: 'Dashboard' },
  { to: '/wallet', label: 'Wallet' },
  { to: '/logs', label: 'Daily Logs' },
  { to: '/insights', label: 'AI Insights' },
]

export function AppShell() {
  const { user, signOut } = useAuth()

  return (
    <div className="page-wrap">
      <header className="topbar animate-rise">
        <Link to="/wallet" className="brand">
          EchoMirror Butler
        </Link>
        <nav className="main-nav">
          {navItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) => (isActive ? 'active' : '')}
            >
              {item.label}
            </NavLink>
          ))}
        </nav>
        <div className="user-actions">
          <span>{user?.email ?? 'Signed in user'}</span>
          <button type="button" onClick={() => void signOut()}>
            Sign out
          </button>
        </div>
      </header>

      <main className="content animate-stagger">
        <Outlet />
      </main>
    </div>
  )
}
