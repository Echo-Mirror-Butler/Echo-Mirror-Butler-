/**
 * NotificationDrawer  (#262)
 *
 * Slide-in panel listing unread mood-comment notifications.
 * Toggled by the 🔔 bell button in app-shell.tsx.
 * Closes on outside-click or Escape.
 */
import { useEffect, useRef } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'
import { formatDateTime } from '../../lib/date'
import { useFocusTrap } from '../../hooks/use-focus-trap'

type Notification = {
  id: string
  created_at: string
  sentiment: string
  comment_preview: string
  is_read: boolean
}

const SENTIMENT_EMOJI: Record<string, string> = {
  happy: '😊',
  sad: '😔',
  stressed: '😤',
  calm: '😌',
  anxious: '😰',
}

async function fetchUnread(userId: string): Promise<Notification[]> {
  const { data, error } = await supabase
    .from('mood_comment_notifications')
    .select('id, created_at, sentiment, comment_preview, is_read')
    .eq('user_id', userId)
    .eq('is_read', false)
    .order('created_at', { ascending: false })
    .limit(20)

  if (error) throw error
  return (data ?? []) as Notification[]
}

async function markOneRead(id: string) {
  const { error } = await supabase
    .from('mood_comment_notifications')
    .update({ is_read: true })
    .eq('id', id)
  if (error) throw error
}

async function markAllRead(userId: string) {
  const { error } = await supabase
    .from('mood_comment_notifications')
    .update({ is_read: true })
    .eq('user_id', userId)
    .eq('is_read', false)
  if (error) throw error
}

function relativeTime(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime()
  const mins = Math.floor(diff / 60_000)
  if (mins < 1) return 'just now'
  if (mins < 60) return `${mins} min ago`
  const hrs = Math.floor(mins / 60)
  if (hrs < 24) return `${hrs}h ago`
  return formatDateTime(iso)
}

type Props = {
  isOpen: boolean
  onClose: () => void
}

export function NotificationDrawer({ isOpen, onClose }: Props) {
  const { user } = useAuth()
  const qc = useQueryClient()
  const panelRef = useRef<HTMLDivElement>(null)

  const notificationsQuery = useQuery({
    queryKey: ['unread-notifications-list', user?.id],
    queryFn: () => fetchUnread(user!.id),
    enabled: isOpen && Boolean(user?.id),
  })

  const markOneMutation = useMutation({
    mutationFn: (id: string) => markOneRead(id),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ['unread-notifications', user?.id] })
      void qc.invalidateQueries({ queryKey: ['unread-notifications-list', user?.id] })
    },
  })

  const markAllMutation = useMutation({
    mutationFn: () => markAllRead(user!.id),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ['unread-notifications', user?.id] })
      void qc.invalidateQueries({ queryKey: ['unread-notifications-list', user?.id] })
    },
  })

  // Trap focus while open, close on Escape, restore focus to trigger on close
  useFocusTrap(isOpen, onClose, panelRef)

  // Close on outside click
  useEffect(() => {
    if (!isOpen) return
    const handler = (e: MouseEvent) => {
      if (panelRef.current && !panelRef.current.contains(e.target as Node)) {
        onClose()
      }
    }
    // Delay one tick to avoid closing immediately on the open-click
    const id = setTimeout(() => document.addEventListener('mousedown', handler), 0)
    return () => {
      clearTimeout(id)
      document.removeEventListener('mousedown', handler)
    }
  }, [isOpen, onClose])

  if (!isOpen) return null

  const items = notificationsQuery.data ?? []

  return (
    <div
      ref={panelRef}
      role="dialog"
      aria-label="Notifications"
      aria-modal="true"
      tabIndex={-1}
      className="notification-drawer"
      style={{
        position: 'absolute',
        top: '100%',
        right: 0,
        zIndex: 200,
        width: 'min(380px, 94vw)',
        background: 'var(--surface)',
        border: '1px solid var(--line)',
        borderRadius: 'var(--radius)',
        boxShadow: 'var(--shadow)',
        padding: '1rem',
      }}
    >
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem' }}>
        <strong style={{ fontSize: '0.95rem', color: 'var(--text)' }}>Notifications</strong>
        {items.length > 0 && (
          <button
            type="button"
            onClick={() => markAllMutation.mutate()}
            disabled={markAllMutation.isPending}
            style={{ fontSize: '0.75rem', color: 'var(--brand)', background: 'none', border: 'none', cursor: 'pointer' }}
          >
            Mark all as read
          </button>
        )}
      </div>

      {notificationsQuery.isLoading && (
        <p style={{ color: 'var(--muted)', fontSize: '0.85rem' }}>Loading…</p>
      )}

      {!notificationsQuery.isLoading && items.length === 0 && (
        <p style={{ color: 'var(--muted)', fontSize: '0.85rem', textAlign: 'center', padding: '1.5rem 0' }}>
          No new notifications
        </p>
      )}

      <ul style={{ listStyle: 'none', margin: 0, padding: 0, display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
        {items.map((n) => (
          <li
            key={n.id}
            onClick={() => markOneMutation.mutate(n.id)}
            style={{
              display: 'flex',
              gap: '0.6rem',
              alignItems: 'flex-start',
              padding: '0.6rem',
              borderRadius: '10px',
              cursor: 'pointer',
              background: 'var(--surface-soft)',
              transition: 'opacity 0.15s',
            }}
          >
            <span style={{ fontSize: '1.3rem', lineHeight: 1 }}>
              {SENTIMENT_EMOJI[n.sentiment?.toLowerCase()] ?? '💬'}
            </span>
            <div style={{ flex: 1, minWidth: 0 }}>
              <p style={{ margin: 0, fontSize: '0.82rem', color: 'var(--text)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                {n.comment_preview?.slice(0, 80) ?? '(no preview)'}
              </p>
              <p style={{ margin: '2px 0 0', fontSize: '0.72rem', color: 'var(--muted)' }}>
                {relativeTime(n.created_at)}
              </p>
            </div>
          </li>
        ))}
      </ul>
    </div>
  )
}
