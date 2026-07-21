import { useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { useAuth } from '../../lib/auth-context'
import { toDateInputValue } from '../../lib/date'
import { LogEntryForm, LogFormMode } from './components/log-entry-form'

type LogFormPageProps = {
  mode: LogFormMode
}

export function LogFormPage({ mode }: LogFormPageProps) {
  const navigate = useNavigate()
  const { id } = useParams()
  const { user } = useAuth()
  const [searchParams] = useSearchParams()

  const initialDate = searchParams.get('date') ?? toDateInputValue(new Date())

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

        <LogEntryForm
          mode={mode}
          id={id}
          initialDate={initialDate}
          onSuccess={() => navigate('/logs')}
          onExistingFound={(existingId) => navigate(`/logs/${existingId}/edit`, { replace: true })}
          onDeleteSuccess={() => navigate('/logs')}
        />
      </article>
    </section>
  )
}