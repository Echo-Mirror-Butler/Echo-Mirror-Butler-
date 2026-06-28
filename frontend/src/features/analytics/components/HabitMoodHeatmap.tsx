import { useRef, useState } from 'react'
import { toPng } from 'html-to-image'
import { buildHabitMoodHeatmap } from '../analytics-helpers'
import type { AnalyticsLogEntry } from '../analytics-helpers'

const MOOD_LABELS = ['😢 1', '😕 2', '😐 3', '🙂 4', '😄 5']
const MOOD_SCORES = [1, 2, 3, 4, 5]
const BRAND_RGB = '20, 99, 255'

type Props = {
  entries: Pick<AnalyticsLogEntry, 'mood' | 'habits'>[]
}

export function HabitMoodHeatmap({ entries }: Props) {
  const gridRef = useRef<HTMLDivElement>(null)
  const [copying, setCopying] = useState(false)

  const rows = buildHabitMoodHeatmap(entries as AnalyticsLogEntry[])

  if (rows.length === 0) return null

  const maxCount = Math.max(...rows.flatMap((r) => Object.values(r.counts)))

  function cellBg(count: number): string {
    if (maxCount === 0 || count === 0) return 'var(--surface-soft)'
    const intensity = count / maxCount
    return `rgba(${BRAND_RGB}, ${Math.max(0.12, intensity)})`
  }

  async function handleCopy() {
    if (!gridRef.current) return
    setCopying(true)
    try {
      const dataUrl = await toPng(gridRef.current, { backgroundColor: 'var(--surface)' })
      const a = document.createElement('a')
      a.href = dataUrl
      a.download = 'habit-mood-heatmap.png'
      a.click()
    } finally {
      setCopying(false)
    }
  }

  const colWidth = '3rem'
  const labelWidth = '9rem'

  return (
    <div>
      <div ref={gridRef} style={{ overflowX: 'auto', paddingBottom: '0.25rem' }}>
        {/* Header row */}
        <div style={{ display: 'flex', gap: '4px', marginBottom: '4px', paddingLeft: labelWidth }}>
          {MOOD_LABELS.map((label) => (
            <div
              key={label}
              style={{
                width: colWidth,
                flexShrink: 0,
                textAlign: 'center',
                fontSize: '0.75rem',
                fontWeight: 600,
                color: 'var(--muted)',
              }}
            >
              {label}
            </div>
          ))}
        </div>

        {/* Data rows */}
        {rows.map((row) => (
          <div
            key={row.habit}
            style={{ display: 'flex', gap: '4px', marginBottom: '4px', alignItems: 'center' }}
          >
            <div
              style={{
                width: labelWidth,
                flexShrink: 0,
                fontSize: '0.8rem',
                color: 'var(--text)',
                fontWeight: 500,
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap',
                paddingRight: '0.5rem',
              }}
              title={row.habit}
            >
              {row.habit}
            </div>
            {MOOD_SCORES.map((score) => {
              const count = row.counts[score] ?? 0
              return (
                <div
                  key={score}
                  title={`${row.habit} logged on ${count} day${count !== 1 ? 's' : ''} when mood was ${score}`}
                  style={{
                    width: colWidth,
                    height: '2.2rem',
                    flexShrink: 0,
                    borderRadius: '6px',
                    background: cellBg(count),
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontSize: '0.75rem',
                    fontWeight: 600,
                    color: count > 0 && count / maxCount > 0.5 ? '#fff' : 'var(--text)',
                    border: '1px solid var(--line)',
                    transition: 'opacity 0.15s',
                    cursor: 'default',
                  }}
                >
                  {count > 0 ? count : ''}
                </div>
              )
            })}
          </div>
        ))}
      </div>

      <div style={{ marginTop: '0.75rem', display: 'flex', alignItems: 'center', gap: '1rem' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', fontSize: '0.78rem', color: 'var(--muted)' }}>
          <span
            style={{
              display: 'inline-block',
              width: '1rem',
              height: '1rem',
              borderRadius: '3px',
              background: 'var(--surface-soft)',
              border: '1px solid var(--line)',
            }}
          />
          0
          <span
            style={{
              display: 'inline-block',
              width: '1rem',
              height: '1rem',
              borderRadius: '3px',
              background: `rgba(${BRAND_RGB}, 0.5)`,
            }}
          />
          mid
          <span
            style={{
              display: 'inline-block',
              width: '1rem',
              height: '1rem',
              borderRadius: '3px',
              background: `rgba(${BRAND_RGB}, 1)`,
            }}
          />
          max
        </div>

        <button
          type="button"
          className="chip"
          style={{ marginLeft: 'auto', fontSize: '0.8rem' }}
          onClick={() => void handleCopy()}
          disabled={copying}
        >
          {copying ? 'Saving…' : 'Copy as image'}
        </button>
      </div>
    </div>
  )
}
