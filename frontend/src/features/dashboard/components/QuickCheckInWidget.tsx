import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { supabase } from '../../../lib/supabase'
import { useAuth } from '../../../lib/auth-context'
import { toDateInputValue } from '../../../lib/date'

const MOOD_EMOJIS = ['😞', '😕', '😐', '🙂', '😄']
const MOOD_LABELS = ['Very sad', 'Sad', 'Neutral', 'Happy', 'Very happy']
const MAX_NOTE_LENGTH = 120

function getTodayDate() {
  return toDateInputValue(new Date())
}

export function QuickCheckInWidget() {
  const { user } = useAuth()
  const queryClient = useQueryClient()
  const [selectedMood, setSelectedMood] = useState<number | null>(null)
  const [note, setNote] = useState('')
  const [submitted, setSubmitted] = useState(false)

  const todayLogQuery = useQuery({
    queryKey: ['today-log', user?.id],
    queryFn: async () => {
      if (!user) return null
      const today = getTodayDate()
      const start = new Date(`${today}T00:00:00.000Z`).toISOString()
      const end = new Date(`${today}T23:59:59.999Z`).toISOString()

      const { data, error } = await supabase
        .from('log_entries')
        .select('id, mood, notes')
        .eq('user_id', user.id)
        .gte('date', start)
        .lte('date', end)
        .maybeSingle()

      if (error) throw error
      return data
    },
    enabled: !!user,
    staleTime: 60_000,
  })

  const createLogMutation = useMutation({
    mutationFn: async () => {
      if (!user || selectedMood === null) throw new Error('Missing data')

      const today = getTodayDate()
      const { data, error } = await supabase
        .from('log_entries')
        .insert({
          user_id: user.id,
          date: new Date(`${today}T12:00:00.000Z`).toISOString(),
          mood: selectedMood,
          habits: [],
          notes: note.trim() || null,
        })
        .select('id')
        .single()

      if (error) throw error
      return data
    },
    onSuccess: () => {
      setSubmitted(true)
      queryClient.invalidateQueries({ queryKey: ['today-log', user?.id] })
      queryClient.invalidateQueries({ queryKey: ['logs', user?.id] })
      queryClient.invalidateQueries({ queryKey: ['dashboard-streak', user?.id] })
      queryClient.invalidateQueries({ queryKey: ['achievement-progress', user?.id] })
    },
  })

  if (todayLogQuery.data && !submitted) {
    return (
      <div className="quick-checkin-card quick-checkin-card--done">
        <div className="quick-checkin-done">
          <span className="quick-checkin-done-icon">✓</span>
          <span>Logged today</span>
        </div>
        <Link to={`/logs/${todayLogQuery.data.id}`} className="quick-checkin-link">
          View log →
        </Link>
      </div>
    )
  }

  if (submitted) {
    return (
      <div className="quick-checkin-card quick-checkin-card--success">
        <div className="quick-checkin-success">
          <span className="quick-checkin-success-icon">✓</span>
          <span>Logged today — +1 ECHO earned 🎉</span>
        </div>
        <Link
          to={`/logs/new?mood=${selectedMood}&notes=${encodeURIComponent(note)}`}
          className="quick-checkin-link"
        >
          Add more detail →
        </Link>
      </div>
    )
  }

  return (
    <div className="quick-checkin-card">
      <h3 className="quick-checkin-title">How are you feeling?</h3>

      <div role="radiogroup" aria-label="Mood selection" className="quick-checkin-moods">
        {MOOD_EMOJIS.map((emoji, index) => (
          <button
            key={index}
            role="radio"
            aria-checked={selectedMood === index}
            aria-label={`${MOOD_LABELS[index]}, mood ${index + 1}`}
            onClick={() => setSelectedMood(index)}
            onKeyDown={(e) => {
              if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
                e.preventDefault()
                setSelectedMood((prev) => (prev === null ? 0 : Math.min(prev + 1, 4)))
              } else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
                e.preventDefault()
                setSelectedMood((prev) => (prev === null ? 4 : Math.max(prev - 1, 0)))
              }
            }}
            className={`quick-checkin-mood-btn ${selectedMood === index ? 'quick-checkin-mood-btn--selected' : ''}`}
          >
            <span className="quick-checkin-mood-emoji">{emoji}</span>
            <span className="quick-checkin-mood-label">{MOOD_LABELS[index]}</span>
          </button>
        ))}
      </div>

      <div className="quick-checkin-note">
        <textarea
          value={note}
          onChange={(e) => setNote(e.target.value.slice(0, MAX_NOTE_LENGTH))}
          placeholder="One thing on your mind?"
          maxLength={MAX_NOTE_LENGTH}
          rows={2}
          className="quick-checkin-textarea"
          aria-label="Optional note"
        />
        <span className="quick-checkin-char-count">{note.length}/{MAX_NOTE_LENGTH}</span>
      </div>

      <button
        onClick={() => createLogMutation.mutate()}
        disabled={selectedMood === null || createLogMutation.isPending}
        className="quick-checkin-submit"
      >
        {createLogMutation.isPending ? 'Logging...' : 'Log it'}
      </button>

      {createLogMutation.isError && (
        <p className="quick-checkin-error" role="alert">
          Failed to log. Please try again.
        </p>
      )}
    </div>
  )
}
