import { Link } from 'react-router-dom'

export default function NotFoundPage() {
  return (
    <div className="card empty-state">
      <h1>Page not found</h1>
      <p>The page you're looking for doesn't exist.</p>
      <Link to="/dashboard">Go to Dashboard</Link>
    </div>
  )
}
