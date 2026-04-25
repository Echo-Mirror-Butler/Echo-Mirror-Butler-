import { createBrowserRouter } from 'react-router-dom'

// Placeholder pages - will be replaced by feature implementations
const HomePage = () => (
  <div className="min-h-screen flex items-center justify-center bg-gray-50">
    <div className="text-center">
      <h1 className="text-4xl font-bold text-primary mb-4">EchoMirror Butler</h1>
      <p className="text-gray-600">Your Personal Growth Assistant</p>
    </div>
  </div>
)

export const router = createBrowserRouter([
  {
    path: '/',
    element: <HomePage />,
  },
])
