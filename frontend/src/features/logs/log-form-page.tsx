import { FormEvent, KeyboardEvent, useEffect, useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'
import { useToast } from '../../lib/use-toast'
import type { LogEntry } from '../../lib/types'
import { toDateInputValue } from '../../lib/date'

type LogFormMode = 'create' | 'edit'

type LogFormPageProps = {
  mode: LogFormMode
}

const HABIT_PRESETS = [
  'Exercise', 'Meditation', 'Reading', 'Hydration',
  'Sleep 8h', 'Journaling', 'Healthy eating', 'No alcohol',
  'Gratitude', 'Cold shower',
]

const MOOD_EMOJIS = ['🙁', '😕', '😐', '🙂', '😄']
const MAX_NOTES_LENGTH = 500
const MAX_HABITS = 5

async function fetchLogById(id: string): Promise<LogEntry | null> {
  const { data, error } = await supabase.from('log_entries').select('*').eq('id', id).maybeSingle()
  if (error) {
    throw error
  }

  if (!data) {
    return null
  }

  return {
    ...(data as LogEntry),
    habits: Array.isArray(data.habits) ? data.habits : [],
  }
}

async function findExistingByDate(userId: string, dateValue: string): Promise<string | null> {
  const start = new Date(`${dateValue}T00:00:00.000Z`).toISOString()
  const end = new Date(`${dateValue}T23:59:59.999Z`).toISOString()

  const { data, error } = await supabase
    .from('log_entries')
    .select('id')
    .eq('user_id', userId)
    .gte('date', start)
    .lte('date', end)
    .maybeSingle()

  if (error) {
    throw error
  }

  return (data?.id as string | undefined) ?? null
}

export function LogFormPage({ mode }: LogFormPageProps) {
  const navigate = useNavigate()
  const { id } = useParams()
  const { user } = useAuth()
  const queryClient = useQueryClient()
  const [searchParams] = useSearchParams()

  const initialDate = searchParams.get('date') ?? toDateInputValue(new Date())

  const entryQuery = useQuery({
    queryKey: ['log-entry', id],
    queryFn: () => fetchLogById(id!),
    enabled: mode === 'edit' && Boolean(id),
  })

  const existingEntry = entryQuery.data

  const { showToast } = useToast()

  const [date, setDate] = useState(initialDate)
  const [mood, setMood] = useState<number | null>(null)
  const [habits, setHabits] = useState<string[]>([])
  const [habitInput, setHabitInput] = useState('')
  const [notes, setNotes] = useState('')
  const [formError, setFormError] = useState<string | null>(null)
  const [toast, setToast] = useState<{ show: boolean; message: string; type: 'success' | 'error' } | null>(null)
  const [fieldErrors, setFieldErrors] = useState<{ date?: string; mood?: string; habits?: string; notes?: string }>({})

  const hydrated = useMemo(
    () =>
      mode === 'edit' && existingEntry
        ? {
            date: toDateInputValue(new Date(existingEntry.date)),
            mood: existingEntry.mood,
            habits: existingEntry.habits,
            notes: existingEntry.notes ?? '',
          }
        : null,
    [mode, existingEntry],
  )

  useEffect(() => {
    if (!hydrated) {
      return
    }

    setDate(hydrated.date)
    setMood(hydrated.mood)
    setHabits(hydrated.habits)
    setNotes(hydrated.notes)
  }, [hydrated])

  function validate(): boolean {
    const errors: { date?: string; mood?: string; habits?: string; notes?: string } = {}
    const selectedDate = new Date(date)
    const today = new Date()
    today.setHours(23, 59, 59, 999)
    if (selectedDate > today) {
      errors.date = 'Date cannot be in the future'
    }
    if (mood === null) {
      errors.mood = 'Mood score is required'
    }
    if (notes.length > MAX_NOTES_LENGTH) {
      errors.notes = `Notes must be under ${MAX_NOTES_LENGTH} characters`
    }
    setFieldErrors(errors)
    return Object.keys(errors).length === 0
  }

  const saveMutation = useMutation({
    mutationFn: async () => {
      if (!user) {
        throw new Error('No signed in user found.')
      }

      if (mode === 'create') {
        const existingId = await findExistingByDate(user.id, date)
        if (existingId) {
          navigate(`/logs/${existingId}/edit`, { replace: true })
          return null
        }

        const { data, error } = await supabase
          .from('log_entries')
          .insert({
            user_id: user.id,
            date: new Date(`${date}T12:00:00.000Z`).toISOString(),
            mood,
            habits,
            notes: notes.trim() || null,
          })
          .select('*')
          .single()

        if (error) {
          throw error
        }

        return data as LogEntry
      }

      const { data, error } = await supabase
        .from('log_entries')
        .update({
          date: new Date(`${date}T12:00:00.000Z`).toISOString(),
          mood,
          habits,
          notes: notes.trim() || null,
        })
        .eq('id', id)
        .eq('user_id', user.id)
        .select('*')
        .single()

      if (error) {
        throw error
      }

      return data as LogEntry
    },
    onMutate: () => {
      setFormError(null)
      setToast(null)
      setFieldErrors({})
    },
    onSuccess: async () => {
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ['logs', user?.id] }),
        queryClient.invalidateQueries({ queryKey: ['log-entry', id] }),
      ])
      showToast(mode === 'create' ? 'Mood logged! +1 ECHO earned 🎉' : 'Changes saved', 'success')
      navigate('/logs')
    },
    onError: (error: Error) => {
      setFormError(error.message)
    },
  })

  const deleteMutation = useMutation({
    mutationFn: async () => {
      if (!user || !id) {
        throw new Error('Missing entry id')
      }

      const { error } = await supabase
        .from('log_entries')
        .delete()
        .eq('id', id)
        .eq('user_id', user.id)

      if (error) {
        throw error
      }
    },
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ['logs', user?.id] })
      navigate('/logs')
    },
    onError: (error: Error) => {
      setToast({ show: true, message: error.message, type: 'error' })
    },
  })

  const addHabitFromInput = () => {
    const next = habitInput.trim()
    if (!next) {
      return
    }

    if (habits.length >= MAX_HABITS) {
      return
    }

    if (!habits.includes(next)) {
      setHabits((prev) => [...prev, next])
    }
    setHabitInput('')
  }

  const onHabitKeyDown = (event: KeyboardEvent<HTMLInputElement>) => {
    if (event.key === 'Enter') {
      event.preventDefault()
      addHabitFromInput()
    }
  }

  if (!user) {
    return null
  }

  return (
    <section className="feature-grid">
      {toast && (
        <div className={`toast toast-${toast.type} fixed top-4 right-4 px-6 py-3 rounded shadow-lg z-50`}
          role="alert"
          aria-live="polite"
        >
          {toast.message}
        </div>
      )}
      <article className="card full-width">
        <div className="card-header">
          <h2>{mode === 'create' ? 'New Log Entry' : 'Edit Log Entry'}</h2>
          <button type="button" onClick={() => navigate('/logs')}>
            Back
          </button>
        </div>

        <form
          className="form-stack"
          onSubmit={(event: FormEvent<HTMLFormElement>) => {
            event.preventDefault()
            setFormError(null)
            if (!validate()) return
            saveMutation.mutate()
          }}
        >
          <label>
            Date
            <input type="date" value={date} max={toDateInputValue(new Date())} onChange={(event) => { setDate(event.target.value); setFieldErrors((prev) => ({ ...prev, date: undefined })) }} />
            {fieldErrors.date && <p className="error-text" style={{ marginTop: '0.25rem' }}>{fieldErrors.date}</p>}
          </label>

          <div>
            <p className="field-label">Mood</p>
            <div className="chip-row">
              {MOOD_EMOJIS.map((emoji, idx) => {
                const value = idx + 1
                return (
                  <button
                    key={value}
                    type="button"
                    style={{ fontSize: '1.3rem', padding: '0.5rem 0.8rem' }}
                    className={mood === value ? 'chip active' : 'chip'}
                    onClick={() => {
                      setMood((prev) => (prev === value ? null : value))
                      setFieldErrors((prev) => ({ ...prev, mood: undefined }))
                    }}
                    aria-label={`Mood ${value}`}
                  >
                    {emoji}
                  </button>
                )
              })}
            </div>
            {fieldErrors.mood && <p className="error-text" style={{ marginTop: '0.25rem' }}>{fieldErrors.mood}</p>}
          </div>

          <div>
            <p className="field-label">Habits (max {MAX_HABITS})</p>
            <div className="chip-row">
              {HABIT_PRESETS.map((preset) => (
                <button
                  key={preset}
                  type="button"
                  className={habits.includes(preset) ? 'chip active' : 'chip'}
                  onClick={() =>
                    setHabits((prev) =>
                      prev.includes(preset) ? prev.filter((h) => h !== preset) : [...prev, preset],
                    )
                  }
                >
                  {preset}
                </button>
              ))}
            </div>
            <input
              type="text"
              value={habitInput}
              onChange={(event) => setHabitInput(event.target.value)}
              onKeyDown={onHabitKeyDown}
              placeholder="Type a habit and press Enter"
            />
            <div className="chip-row compact">
              {habits.map((habit) => (
                <button
                  type="button"
                  key={habit}
                  className="chip active"
                  onClick={() => setHabits((prev) => prev.filter((item) => item !== habit))}
                >
                  {habit} ×
                </button>
              ))}
            </div>
            {habits.length >= MAX_HABITS && (
              <p className="muted" style={{ fontSize: '0.8rem', margin: '0.25rem 0 0' }}>
                Maximum {MAX_HABITS} habits reached
              </p>
            )}
          </div>

          <label>
            Notes
            <textarea
              rows={4}
              value={notes}
              onChange={(event) => { setNotes(event.target.value); setFieldErrors((prev) => ({ ...prev, notes: undefined })) }}
              placeholder="Optional notes"
              maxLength={MAX_NOTES_LENGTH}
            />
            <span className="muted" style={{ fontSize: '0.8rem', marginTop: '0.2rem', display: 'block', textAlign: 'right' }}>
              {notes.length}/{MAX_NOTES_LENGTH}
            </span>
            {fieldErrors.notes && <p className="error-text" style={{ marginTop: '0.25rem' }}>{fieldErrors.notes}</p>}
          </label>

          <button type="submit" disabled={saveMutation.isPending}>
            {saveMutation.isPending ? 'Saving…' : 'Save log entry'}
          </button>

          {mode === 'edit' ? (
            <button
              type="button"
              className="danger"
              onClick={() => {
                const shouldDelete = window.confirm('Delete this log entry? This cannot be undone.')
                if (shouldDelete) {
                  deleteMutation.mutate()
                }
              }}
              disabled={deleteMutation.isPending}
            >
              {deleteMutation.isPending ? 'Deleting…' : 'Delete entry'}
            </button>
          ) : null}

          {formError && <p className="error-text">{formError}</p>}
        </form>
      </article>
    </section>
  )
}