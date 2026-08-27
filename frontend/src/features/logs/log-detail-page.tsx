import { Link, useNavigate, useParams } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'
import type { LogEntry } from '../../lib/types'
import { moodToEmoji } from '../../lib/date'
import { LogImageThumbnail } from './components/log-image-thumbnail'

const MOOD_COLORS: Record<number, string> = {
  1: '#ef4444',
  2: '#f97316',
  3: '#eab308',
  4: '#84cc16',
  5: '#22c55e',
}

async function fetchLogById(id: string): Promise<LogEntry | null> {
  const { data, error } = await supabase.from('log_entries').select('*').eq('id', id).maybeSingle()
  if (error) throw error
  if (!data) return null
  return { ...(data as LogEntry), habits: Array.isArray(data.habits) ? data.habits : [] }
}

async function fetchEchoReward(logId: string): Promise<number | null> {
  try {
    const { data } = await supabase
      .from('echo_rewards')
      .select('amount')
      .eq('log_entry_id', logId)
      .maybeSingle()
    return data?.amount ?? null
  } catch {
    return null
  }
}

export function LogDetailPage() {
  const { id } = useParams<{ id: string }>()
  const { user } = useAuth()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [shareToast, setShareToast] = useState(false)

  const entryQuery = useQuery({
    queryKey: ['log-entry', id],
    queryFn: () => fetchLogById(id!),
    enabled: Boolean(id),
  })

  const rewardQuery = useQuery({
    queryKey: ['echo-reward', id],
    queryFn: () => fetchEchoReward(id!),
    enabled: Boolean(id),
  })

  const deleteMutation = useMutation({
    mutationFn: async () => {
      const { error } = await supabase
        .from('log_entries')
        .delete()
        .eq('id', id!)
        .eq('user_id', user!.id)
      if (error) throw error
    },
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ['logs', user?.id] })
      navigate('/logs')
    },
  })

  const handleDuplicate = () => {
    if (!entry) return
    const params = new URLSearchParams()
    params.set('mood', String(entry.mood ?? ''))
    if (entry.habits.length > 0) params.set('habits', entry.habits.join(','))
    if (entry.notes) params.set('notes', entry.notes)
    navigate(`/logs/new?${params.toString()}`)
  }

  const handleShare = async () => {
    if (!entry) return
    const emoji = moodToEmoji(entry.mood)
    const text = `Mood: ${emoji} ${entry.mood}/5${entry.habits.length > 0 ? ` · Habits: ${entry.habits.join(', ')}` : ''}`

    if (navigator.share) {
      try {
        await navigator.share({
          title: `My mood today: ${emoji}`,
          text,
          url: window.location.href,
        })
      } catch {
        // User cancelled
      }
    } else {
      try {
        await navigator.clipboard.writeText(`${text}\n${window.location.href}`)
        setShareToast(true)
        setTimeout(() => setShareToast(false), 2000)
      } catch {
        // Clipboard unavailable
      }
    }
  }

  if (!user) return null

  if (entryQuery.isLoading) {
    return (
      <section className="feature-grid">
        <article className="card full-width">
          <div className="skeleton-line large" />
          <div className="skeleton-line" />
          <div className="skeleton-line" />
        </article>
      </section>
    )
  }

  const entry = entryQuery.data
  if (!entry) {
    return (
      <section className="feature-grid">
        <article className="card full-width">
          <p className="muted">Log entry not found.</p>
          <Link to="/logs" style={{ display: 'inline-block', marginTop: '1rem' }}>
            ← Back to logs
          </Link>
        </article>
      </section>
    )
  }

  const moodColor = entry.mood ? MOOD_COLORS[entry.mood] : '#6b7280'
  const moodPct = entry.mood ? (entry.mood / 5) * 100 : 0

  return (
    <section className="feature-grid">
      <article className="card full-width">
        <div className="card-header">
          <Link to="/logs" style={{ fontSize: '0.875rem', textDecoration: 'none' }}>
            ← Back
          </Link>
          <h2>
            {new Intl.DateTimeFormat(undefined, {
              weekday: 'long',
              year: 'numeric',
              month: 'long',
              day: 'numeric',
            }).format(new Date(entry.date))}
          </h2>
          <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
            <Link to={`/logs/${id}/edit`}>
              <button type="button">Edit</button>
            </Link>
            <button type="button" onClick={handleDuplicate}>
              Duplicate
            </button>
            <button type="button" onClick={handleShare}>
              {shareToast ? 'Copied!' : 'Share'}
            </button>
            <button
              type="button"
              className="danger"
              onClick={() => {
                if (window.confirm('Delete this log entry? This cannot be undone.')) {
                  deleteMutation.mutate()
                }
              }}
              disabled={deleteMutation.isPending}
            >
              {deleteMutation.isPending ? 'Deleting…' : 'Delete'}
            </button>
          </div>
        </div>

        {deleteMutation.error ? (
          <p className="error-text">{(deleteMutation.error as Error).message}</p>
        ) : null}

        <div className="form-stack" style={{ marginTop: '1.5rem' }}>
          <div>
            <p className="field-label">Mood</p>
            <p style={{ fontSize: '1.5rem', marginBottom: '0.5rem' }}>
              {moodToEmoji(entry.mood)} {entry.mood ?? '—'}/5
            </p>
            <div
              style={{
                background: '#e5e7eb',
                borderRadius: '9999px',
                height: '8px',
                overflow: 'hidden',
                maxWidth: '240px',
              }}
            >
              <div
                style={{
                  width: `${moodPct}%`,
                  height: '100%',
                  background: moodColor,
                  borderRadius: '9999px',
                  transition: 'width 0.3s ease',
                }}
              />
            </div>
          </div>

          {entry.notes ? (
            <div>
              <p className="field-label">Notes</p>
              <p style={{ whiteSpace: 'pre-wrap', lineHeight: 1.6 }}>{entry.notes}</p>
            </div>
          ) : null}

          {entry.image_path ? (
            <div>
              <p className="field-label">Photo</p>
              <LogImageThumbnail path={entry.image_path} alt="Log entry attachment" size={220} />
            </div>
          ) : null}

          {entry.habits.length > 0 ? (
            <div>
              <p className="field-label">Habits</p>
              <div className="chip-row">
                {entry.habits.map((habit) => (
                  <span className="chip active" key={habit}>
                    {habit}
                  </span>
                ))}
              </div>
            </div>
          ) : null}

          {rewardQuery.data != null ? (
            <div>
              <span
                className="chip active"
                style={{ background: '#fbbf24', color: '#1c1917', fontWeight: 600 }}
              >
                Earned {rewardQuery.data} ECHO
              </span>
            </div>
          ) : null}
        </div>
      </article>
    </section>
  )
}

