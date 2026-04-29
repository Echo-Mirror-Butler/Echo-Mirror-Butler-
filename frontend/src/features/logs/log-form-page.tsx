import { FormEvent, KeyboardEvent, useEffect, useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'
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

  const [date, setDate] = useState(initialDate)
  const [mood, setMood] = useState<number | null>(null)
  const [habits, setHabits] = useState<string[]>([])
  const [habitInput, setHabitInput] = useState('')
  const [notes, setNotes] = useState('')
  const [formError, setFormError] = useState<string | null>(null)

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

  const saveMutation = useMutation({
    mutationFn: async () => {
      if (!user) {
        throw new Error('No signed in user found.')
      }

      if (!mood && habits.length === 0 && !notes.trim()) {
        throw new Error('Fill at least one field: mood, habit, or note.')
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
    },
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ['logs', user?.id] })
      await queryClient.invalidateQueries({ queryKey: ['log-entry', id] })
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
      setFormError(error.message)
    },
  })

  const addHabitFromInput = () => {
    const next = habitInput.trim()
    if (!next) {
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
            saveMutation.mutate()
          }}
        >
          <label>
            Date
            <input type="date" value={date} onChange={(event) => setDate(event.target.value)} />
          </label>

          <div>
            <p className="field-label">Mood</p>
            <div className="chip-row">
              {[1, 2, 3, 4, 5].map((value) => (
                <button
                  key={value}
                  type="button"
                  className={mood === value ? 'chip active' : 'chip'}
                  onClick={() => setMood((prev) => (prev === value ? null : value))}
                >
                  {value}
                </button>
              ))}
            </div>
          </div>

          <div>
            <p className="field-label">Habits</p>
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
          </div>

          <label>
            Notes
            <textarea
              rows={4}
              value={notes}
              onChange={(event) => setNotes(event.target.value)}
              placeholder="Optional notes"
            />
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

          {formError ? <p className="error-text">{formError}</p> : null}
        </form>
      </article>
    </section>
  )
}
