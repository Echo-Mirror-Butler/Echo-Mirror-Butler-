import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../../lib/auth-context'
import { supabase } from '../../lib/supabase'
import './onboarding-page.css'

function ConfettiBlast() {
  return (
    <div className="confetti-wrap" aria-hidden="true">
      {Array.from({ length: 24 }).map((_, i) => (
        <span key={i} style={{ ['--piece-delay' as string]: `${i * 35}ms` }} />
      ))}
    </div>
  )
}

export function OnboardingPage() {
  const navigate = useNavigate()
  const { user } = useAuth()
  const [step, setStep] = useState(1)
  const [moodValue, setMoodValue] = useState(5)
  const [reminderTime, setReminderTime] = useState('09:00')
  const [saving, setSaving] = useState(false)

  const markComplete = async () => {
    await supabase.auth.updateUser({ data: { onboarding_completed: true } })
  }

  const handleSkip = async () => {
    await markComplete()
    navigate('/dashboard', { replace: true })
  }

  const handleSaveMood = async () => {
    if (!user) return
    setSaving(true)
    try {
      await supabase.from('log_entries').insert({
        user_id: user.id,
        date: new Date().toISOString(),
        mood: Math.round(moodValue / 2),
        habits: [],
        notes: 'Onboarding mood baseline',
      })
      setStep(3)
    } catch {
      setStep(3)
    } finally {
      setSaving(false)
    }
  }

  const handleSaveReminder = async () => {
    await supabase.auth.updateUser({ data: { reminder_time: reminderTime } })
    await markComplete()
    setStep(4)
  }

  const handleSkipReminder = async () => {
    await markComplete()
    setStep(4)
  }

  const moodLabel = (v: number) => {
    if (v <= 2) return 'Struggling'
    if (v <= 4) return 'Low'
    if (v <= 6) return 'Okay'
    if (v <= 8) return 'Good'
    return 'Great'
  }

  return (
    <div className="onboarding-root">
      {step === 4 && <ConfettiBlast />}
      <div className="onboarding-card animate-rise">
        <div className="onboarding-progress">
          {[1, 2, 3, 4].map((s) => (
            <span
              key={s}
              className={`onboarding-dot${s === step ? ' active' : ''}${s < step ? ' done' : ''}`}
            />
          ))}
        </div>
        <p className="muted" style={{ textAlign: 'center', marginBottom: '1rem', fontSize: '0.82rem' }}>
          Step {step} of 4
        </p>

        {step === 1 && (
          <>
            <h2 className="onboarding-title">Welcome to EchoMirror</h2>
            <p className="onboarding-sub">Your personal growth companion. Here's what you can do:</p>
            <div className="onboarding-bullets">
              <div className="onboarding-bullet">
                <span className="onboarding-bullet-icon">📝</span>
                <span><strong>Track your mood daily</strong> — log how you feel and spot patterns over time</span>
              </div>
              <div className="onboarding-bullet">
                <span className="onboarding-bullet-icon">✨</span>
                <span><strong>Get AI-powered insights</strong> — personalised reflections based on your history</span>
              </div>
              <div className="onboarding-bullet">
                <span className="onboarding-bullet-icon">💎</span>
                <span><strong>Earn ECHO tokens</strong> — consistency rewards you with real Stellar tokens</span>
              </div>
            </div>
            <div className="onboarding-actions">
              <button type="button" onClick={() => setStep(2)}>Get started</button>
              <button type="button" className="skip-btn" onClick={handleSkip}>Skip for now</button>
            </div>
          </>
        )}

        {step === 2 && (
          <>
            <h2 className="onboarding-title">How are you feeling?</h2>
            <p className="onboarding-sub">Set your mood baseline — this saves your first log entry.</p>
            <div className="onboarding-slider-wrap">
              <span className="onboarding-slider-value">{moodValue}</span>
              <span style={{ color: 'var(--muted)', fontSize: '0.9rem' }}>{moodLabel(moodValue)}</span>
              <input
                type="range"
                className="onboarding-slider"
                min={1}
                max={10}
                value={moodValue}
                onChange={(e) => setMoodValue(Number(e.target.value))}
              />
              <div className="onboarding-slider-labels">
                <span>1 — Low</span>
                <span>10 — Great</span>
              </div>
            </div>
            <div className="onboarding-actions">
              <button type="button" onClick={handleSaveMood} disabled={saving}>
                {saving ? 'Saving…' : 'Next'}
              </button>
              <button type="button" className="skip-btn" onClick={handleSkip}>Skip</button>
            </div>
          </>
        )}

        {step === 3 && (
          <>
            <h2 className="onboarding-title">Daily reminder</h2>
            <p className="onboarding-sub">Set a time to remind you to log your mood each day (optional).</p>
            <div className="onboarding-time-wrap">
              <input
                type="time"
                value={reminderTime}
                onChange={(e) => setReminderTime(e.target.value)}
              />
            </div>
            <div className="onboarding-actions">
              <button type="button" onClick={handleSaveReminder}>Set reminder & finish</button>
              <button type="button" className="skip-btn" onClick={handleSkipReminder}>Skip</button>
            </div>
          </>
        )}

        {step === 4 && (
          <>
            <div className="onboarding-done-icon">🎉</div>
            <h2 className="onboarding-title">You're all set!</h2>
            <p className="onboarding-sub">Your first mood log is saved. Explore your dashboard to see insights, track habits, and more.</p>
            <div className="onboarding-actions">
              <button type="button" onClick={() => navigate('/dashboard', { replace: true })}>
                Go to Dashboard
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  )
}
