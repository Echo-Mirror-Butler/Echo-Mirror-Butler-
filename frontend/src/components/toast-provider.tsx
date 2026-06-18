import { type ReactNode, useEffect, useState } from 'react'
import { getErrorMessage, generateErrorReferenceCode } from '../lib/error-reference'

type Toast = {
  id: string
  title: string
  message: string
  referenceCode?: string
}

type ToastEventDetail = Omit<Toast, 'id'>

const toastEventName = 'echomirror:toast'

export function showErrorToast(detail: ToastEventDetail) {
  if (typeof window === 'undefined') return

  window.dispatchEvent(new CustomEvent<ToastEventDetail>(toastEventName, { detail }))
}

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([])

  useEffect(() => {
    const addToast = (detail: ToastEventDetail) => {
      const id = generateErrorReferenceCode()
      setToasts((current) => [...current, { id, ...detail }])
      window.setTimeout(() => {
        setToasts((current) => current.filter((toast) => toast.id !== id))
      }, 7000)
    }

    const onToast = (event: Event) => {
      addToast((event as CustomEvent<ToastEventDetail>).detail)
    }

    const onUnhandledRejection = (event: PromiseRejectionEvent) => {
      const referenceCode = generateErrorReferenceCode()
      const message = getErrorMessage(event.reason)
      addToast({
        title: 'Something failed in the background',
        message,
        referenceCode,
      })
      console.warn('[EchoMirror unhandled promise rejection]', {
        referenceCode,
        message,
        reason: event.reason,
        path: window.location.pathname,
        timestamp: new Date().toISOString(),
      })
    }

    window.addEventListener(toastEventName, onToast)
    window.addEventListener('unhandledrejection', onUnhandledRejection)

    return () => {
      window.removeEventListener(toastEventName, onToast)
      window.removeEventListener('unhandledrejection', onUnhandledRejection)
    }
  }, [])

  return (
    <>
      {children}
      <div className="toast-viewport" role="status" aria-live="polite">
        {toasts.map((toast) => (
          <article className="toast-card" key={toast.id}>
            <strong>{toast.title}</strong>
            <p>{toast.message}</p>
            {toast.referenceCode ? <small>Ref: {toast.referenceCode}</small> : null}
            <button
              type="button"
              className="toast-dismiss"
              aria-label="Dismiss notification"
              onClick={() => setToasts((current) => current.filter((item) => item.id !== toast.id))}
            >
              ×
            </button>
          </article>
        ))}
      </div>
    </>
  )
}
