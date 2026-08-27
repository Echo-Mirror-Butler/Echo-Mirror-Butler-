import { FormEvent, KeyboardEvent, useEffect, useMemo, useRef, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../lib/auth-context'
import { useToast } from '../../lib/use-toast'
import type { LogEntry } from '../../lib/types'
import { toDateInputValue } from '../../lib/date'
import {
  ALLOWED_LOG_IMAGE_TYPES,
  MAX_LOG_IMAGE_BYTES,
  getLogImageSignedUrl,
  removeLogImage,
  uploadLogImage,
} from '../../lib/log-images'

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

  const imageInputRef = useRef<HTMLInputElement>(null)
  const [existingImagePath, setExistingImagePath] = useState<string | null>(null)
  const [imageFile, setImageFile] = useState<File | null>(null)
  const [imagePreviewUrl, setImagePreviewUrl] = useState<string | null>(null)
  const [removeExistingImage, setRemoveExistingImage] = useState(false)
  const [imageError, setImageError] = useState<string | null>(null)
  const [imageDragOver, setImageDragOver] = useState(false)

  const existingImageUrlQuery = useQuery({
    queryKey: ['log-image-url', existingImagePath],
    queryFn: () => getLogImageSignedUrl(existingImagePath!),
    enabled: Boolean(existingImagePath) && !removeExistingImage,
  })

  const hydrated = useMemo(
    () =>
      mode === 'edit' && existingEntry
        ? {
            date: toDateInputValue(new Date(existingEntry.date)),
            mood: existingEntry.mood,
            habits: existingEntry.habits,
            notes: existingEntry.notes ?? '',
            imagePath: existingEntry.image_path,
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
    setExistingImagePath(hydrated.imagePath)
  }, [hydrated])

  useEffect(() => {
    return () => {
      if (imagePreviewUrl) URL.revokeObjectURL(imagePreviewUrl)
    }
  }, [imagePreviewUrl])

  function selectImageFile(file: File) {
    setImageError(null)
    if (!ALLOWED_LOG_IMAGE_TYPES.includes(file.type)) {
      setImageError('Only PNG, JPG, or WEBP images are allowed.')
      return
    }
    if (file.size > MAX_LOG_IMAGE_BYTES) {
      setImageError(`File is ${(file.size / 1024 / 1024).toFixed(1)} MB — max is 5 MB.`)
      return
    }
    if (imagePreviewUrl) URL.revokeObjectURL(imagePreviewUrl)
    setImageFile(file)
    setImagePreviewUrl(URL.createObjectURL(file))
    setRemoveExistingImage(false)
  }

  function clearImage() {
    if (imagePreviewUrl) URL.revokeObjectURL(imagePreviewUrl)
    setImageFile(null)
    setImagePreviewUrl(null)
    setImageError(null)
    if (existingImagePath) {
      setRemoveExistingImage(true)
    }
  }

  const displayedImageUrl = imagePreviewUrl ?? (!removeExistingImage ? existingImageUrlQuery.data ?? null : null)

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

      let entry: LogEntry

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

        entry = data as LogEntry
      } else {
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

        entry = data as LogEntry
      }

      let imagePath = entry.image_path
      if (removeExistingImage && existingImagePath) {
        await removeLogImage(existingImagePath).catch(() => {})
        imagePath = null
      }
      if (imageFile) {
        imagePath = await uploadLogImage(user.id, entry.id, imageFile)
      }

      if (imagePath !== entry.image_path) {
        const { data: updated, error: imageUpdateError } = await supabase
          .from('log_entries')
          .update({ image_path: imagePath })
          .eq('id', entry.id)
          .select('*')
          .single()

        if (imageUpdateError) {
          throw imageUpdateError
        }

        entry = updated as LogEntry
      }

      return entry
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
        queryClient.invalidateQueries({ queryKey: ['log-image-url'] }),
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

          <div role="radiogroup" aria-label="Mood selection">
            <p className="field-label" id="mood-label">Mood</p>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, minmax(0, 1fr))', gap: '0.4rem', marginTop: '0.45rem' }}>
              {MOOD_EMOJIS.map((emoji, idx) => {
                const value = idx + 1
                const moodLabels = ['Very sad, mood 1', 'Sad, mood 2', 'Neutral, mood 3', 'Happy, mood 4', 'Very happy, mood 5']
                return (
                  <button
                    key={value}
                    type="button"
                    role="radio"
                    style={{ fontSize: '1.3rem', minHeight: '44px', width: '100%', padding: '0.25rem' }}
                    className={mood === value ? 'chip active' : 'chip'}
                    onClick={() => {
                      setMood((prev) => (prev === value ? null : value))
                      setFieldErrors((prev) => ({ ...prev, mood: undefined }))
                    }}
                    aria-label={moodLabels[idx]}
                    aria-pressed={mood === value}
                    aria-checked={mood === value}
                  >
                    {emoji}
                  </button>
                )
              })}
            </div>
            {fieldErrors.mood && <p id="mood-error" className="error-text" style={{ marginTop: '0.25rem' }} role="alert">{fieldErrors.mood}</p>}
          </div>

          <div>
            <p className="field-label">
              Habits{' '}
              <span style={{ color: habits.length >= MAX_HABITS ? 'var(--danger)' : 'inherit' }}>
                {habits.length}/{MAX_HABITS}
              </span>
            </p>
            <div className="chip-row">
              {HABIT_PRESETS.map((preset) => (
                <button
                  key={preset}
                  type="button"
                  className={habits.includes(preset) ? 'chip active' : 'chip'}
                  disabled={habits.length >= MAX_HABITS && !habits.includes(preset)}
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
              disabled={habits.length >= MAX_HABITS}
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
                  style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', paddingRight: '0.4rem' }}
                  onClick={() => setHabits((prev) => prev.filter((item) => item !== habit))}
                >
                  {habit}
                  <span style={{
                    display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
                    minWidth: '22px', minHeight: '22px', borderRadius: '50%',
                    background: 'rgba(0,0,0,0.15)', fontSize: '0.75rem',
                  }}>✕</span>
                </button>
              ))}
            </div>
          </div>

          <label>
            Notes
            <textarea
              rows={4}
              value={notes}
              style={{ minHeight: '120px' }}
              onChange={(event) => { setNotes(event.target.value); setFieldErrors((prev) => ({ ...prev, notes: undefined })) }}
              placeholder="Optional notes"
              maxLength={MAX_NOTES_LENGTH}
            />
            <span style={{
              fontSize: '0.8rem', marginTop: '0.2rem', display: 'block', textAlign: 'right',
              color: MAX_NOTES_LENGTH - notes.length <= 50 ? 'var(--danger)' : 'var(--muted)',
            }}>
              {notes.length}/{MAX_NOTES_LENGTH}
            </span>
            {fieldErrors.notes && <p className="error-text" style={{ marginTop: '0.25rem' }}>{fieldErrors.notes}</p>}
          </label>

          <div>
            <p className="field-label">Photo (optional)</p>
            {displayedImageUrl ? (
              <div style={{ display: 'flex', alignItems: 'flex-start', gap: '0.75rem', marginTop: '0.45rem' }}>
                <img
                  src={displayedImageUrl}
                  alt="Log entry attachment preview"
                  style={{ width: 96, height: 96, objectFit: 'cover', borderRadius: '10px', border: '1px solid var(--line)' }}
                />
                <button type="button" className="secondary" onClick={clearImage}>
                  Remove photo
                </button>
              </div>
            ) : (
              <button
                type="button"
                onClick={() => imageInputRef.current?.click()}
                onDragOver={(event) => { event.preventDefault(); setImageDragOver(true) }}
                onDragLeave={() => setImageDragOver(false)}
                onDrop={(event) => {
                  event.preventDefault()
                  setImageDragOver(false)
                  const file = event.dataTransfer.files[0]
                  if (file) selectImageFile(file)
                }}
                style={{
                  marginTop: '0.45rem',
                  padding: '0.6rem 1rem',
                  borderRadius: '8px',
                  border: `1px dashed ${imageDragOver ? 'var(--brand)' : 'var(--line)'}`,
                  background: imageDragOver ? 'var(--surface-soft)' : 'transparent',
                  cursor: 'pointer',
                  fontSize: '0.85rem',
                  color: 'var(--text)',
                  width: '100%',
                  textAlign: 'center',
                }}
              >
                Drag & drop a photo, or click to browse
              </button>
            )}
            <p className="muted" style={{ margin: '0.35rem 0 0', fontSize: '0.75rem' }}>
              PNG, JPG, or WEBP, max 5 MB
            </p>
            {imageError && <p className="error-text" style={{ marginTop: '0.25rem' }}>{imageError}</p>}
            <input
              ref={imageInputRef}
              type="file"
              accept="image/png,image/jpeg,image/webp"
              style={{ display: 'none' }}
              aria-label="Attach a photo to this log entry"
              onChange={(event) => {
                const file = event.target.files?.[0]
                if (file) selectImageFile(file)
                event.target.value = ''
              }}
            />
          </div>

          <button type="submit" disabled={saveMutation.isPending} style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', justifyContent: 'center' }}>
            {saveMutation.isPending && (
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"
                style={{ animation: 'spin 0.7s linear infinite', flexShrink: 0 }} aria-hidden="true">
                <circle cx="12" cy="12" r="10" strokeOpacity="0.25" />
                <path d="M12 2a10 10 0 0 1 10 10" />
              </svg>
            )}
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