import { createContext, useContext, useState, useCallback, useEffect, type ReactNode } from 'react'

type Toast = {
  id: number
  message: string
  type: 'success' | 'error' | 'info'
}

type ToastContextValue = {
  showToast: (message: string, type: 'success' | 'error' | 'info') => void
}

const ToastContext = createContext<ToastContextValue | undefined>(undefined)

let nextId = 0

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([])

  const showToast = useCallback((message: string, type: 'success' | 'error' | 'info') => {
    const id = nextId++
    setToasts((prev) => {
      const next = [...prev, { id, message, type }]
      return next.length > 3 ? next.slice(next.length - 3) : next
    })
    setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id))
    }, 4000)
  }, [])

  useEffect(() => {
    const handleToastEvent = (event: Event) => {
      const customEvent = event as CustomEvent<{ message: string; type: 'success' | 'error' | 'info' }>
      showToast(customEvent.detail.message, customEvent.detail.type)
    }

    window.addEventListener('app:show-toast', handleToastEvent)
    return () => {
      window.removeEventListener('app:show-toast', handleToastEvent)
    }
  }, [showToast])

  return (
    <ToastContext.Provider value={{ showToast }}>
      {children}
      <div
        role="status"
        aria-live="polite"
        style={{
          position: 'fixed',
          bottom: '1.5rem',
          right: '1.5rem',
          zIndex: 9999,
          display: 'flex',
          flexDirection: 'column',
          gap: '0.5rem',
          pointerEvents: 'none',
        }}
      >
        {toasts.map((toast) => (
          <div
            key={toast.id}
            style={{
              padding: '0.75rem 1.25rem',
              borderRadius: '10px',
              fontSize: '0.88rem',
              fontWeight: 500,
              color: '#fff',
              background: toast.type === 'success' ? 'var(--success)' : toast.type === 'error' ? 'var(--danger)' : 'var(--brand)',
              boxShadow: '0 4px 24px rgba(0,0,0,0.18)',
              animation: 'toast-in 0.25s ease-out',
              maxWidth: '380px',
              pointerEvents: 'auto',
            }}
          >
            {toast.message}
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  )
}

export function useToast() {
  const ctx = useContext(ToastContext)
  if (!ctx) {
    throw new Error('useToast must be used within ToastProvider')
  }
  return ctx
}
