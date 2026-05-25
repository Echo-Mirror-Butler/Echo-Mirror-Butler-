import { useEffect, useRef, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { supabase } from '../../lib/supabase'
import './landing-page.css'

const features = [
  {
    icon: '🧠',
    bg: '#dbeafe',
    title: 'AI Mood Insights',
    desc: 'Your AI companion surfaces personalised reflections shaped by your history — not generic advice.',
  },
  {
    icon: '🌍',
    bg: '#d6f8ef',
    title: 'Global Mirror',
    desc: 'See how your emotional state compares with thousands worldwide, in real time.',
  },
  {
    icon: '📓',
    bg: '#ede9fe',
    title: 'Habit & Mood Logs',
    desc: 'Log what you feel. Over time, patterns emerge you\'d never catch in the moment.',
  },
  {
    icon: '✦',
    bg: '#fef3c7',
    title: 'ECHO Wallet',
    desc: 'Earn ECHO tokens on Stellar just by showing up. Consistency has real value here.',
  },
]

const tickerItems = [
  { flag: '🇬🇧', city: 'London',    mood: 'Calm',       color: '#0a8a5b' },
  { flag: '🇯🇵', city: 'Tokyo',     mood: 'Focused',    color: '#1463ff' },
  { flag: '🇧🇷', city: 'São Paulo', mood: 'Energised',  color: '#e67a00' },
  { flag: '🇺🇸', city: 'New York',  mood: 'Anxious',    color: '#bb2d3b' },
  { flag: '🇮🇳', city: 'Mumbai',    mood: 'Hopeful',    color: '#0a8a5b' },
  { flag: '🇩🇪', city: 'Berlin',    mood: 'Reflective', color: '#8b5cf6' },
  { flag: '🇦🇺', city: 'Sydney',    mood: 'Content',    color: '#1463ff' },
  { flag: '🇳🇬', city: 'Lagos',     mood: 'Motivated',  color: '#0a8a5b' },
]

const wellnessStats = [
  { value: '1 in 4', label: 'people experience a mental health condition each year' },
  { value: '60%',    label: 'of people never seek help due to stigma or lack of access' },
  { value: '40%',    label: 'mood improvement reported by consistent journalling users' },
  { value: '3×',     label: 'more likely to sustain habits when tracking daily mood' },
]

function useReveal() {
  const ref = useRef<HTMLDivElement>(null)
  useEffect(() => {
    const el = ref.current
    if (!el) return
    const observer = new IntersectionObserver(
      ([entry]) => { if (entry.isIntersecting) { el.classList.add('is-visible'); observer.disconnect() } },
      { threshold: 0.1 },
    )
    observer.observe(el)
    return () => observer.disconnect()
  }, [])
  return ref
}

function Reveal({ children, delay = 0, className = '' }: { children: React.ReactNode; delay?: number; className?: string }) {
  const ref = useReveal()
  return <div ref={ref} className={`lp-reveal${delay ? ` lp-reveal-delay-${delay}` : ''} ${className}`}>{children}</div>
}

function WalletConnectSection({ onSignup }: { onSignup: () => void }) {
  const [email, setEmail] = useState('')
  const [status, setStatus] = useState<'idle' | 'loading' | 'done' | 'error'>('idle')
  const [errMsg, setErrMsg] = useState('')

  const handleConnect = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!email.includes('@')) { setErrMsg('Enter a valid email'); return }
    setStatus('loading')
    setErrMsg('')
    const { error } = await supabase.auth.signInWithOtp({ email, options: { shouldCreateUser: true } })
    if (error) { setStatus('error'); setErrMsg(error.message) }
    else { setStatus('done') }
  }

  return (
    <section className="lp-section lp-wallet-section" id="wallet">
      <div className="lp-section-inner">
        <div className="lp-wallet-inner">
          <Reveal>
            <div className="lp-wallet-left">
              <div className="lp-section-eyebrow" style={{ color: '#fbbf24' }}>ECHO Wallet</div>
              <h2 className="lp-section-title" style={{ color: 'white' }}>
                Your wellbeing<br />
                <em style={{ fontStyle: 'italic', color: '#fbbf24' }}>earns real value.</em>
              </h2>
              <p className="lp-section-sub" style={{ color: 'rgba(255,255,255,0.55)' }}>
                Connect your Stellar wallet and start earning ECHO tokens for every mood log, streak, and insight you unlock.
                Consistency has currency here.
              </p>

              <div className="lp-wallet-perks">
                {[
                  { icon: '🔥', title: 'Streak rewards',   desc: 'Log 7 days straight, earn bonus ECHO' },
                  { icon: '✦',  title: 'Stellar native',   desc: 'Real tokens on the Stellar blockchain' },
                  { icon: '🎁', title: 'Send to friends',  desc: 'Gift ECHO to people who inspire you' },
                  { icon: '🔒', title: 'Non-custodial',    desc: 'Your keys, your tokens, always' },
                ].map((p) => (
                  <div key={p.title} className="lp-wallet-perk">
                    <span className="lp-wallet-perk-icon">{p.icon}</span>
                    <div>
                      <div className="lp-wallet-perk-title">{p.title}</div>
                      <div className="lp-wallet-perk-desc">{p.desc}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </Reveal>

          <Reveal delay={2}>
            <div className="lp-wallet-right">
              <div className="lp-wallet-card">
                <div className="lp-wallet-card-glow" />
                <div className="lp-wallet-card-header">
                  <span className="lp-wallet-logo">✦ ECHO</span>
                  <span className="lp-wallet-network">Stellar Network</span>
                </div>
                <div className="lp-wallet-balance-preview">
                  <div className="lp-wallet-balance-label">Your balance</div>
                  <div className="lp-wallet-balance-num">142.00 <span>ECHO</span></div>
                  <div className="lp-wallet-streak">🔥 7-day streak active</div>
                </div>

                {status === 'done' ? (
                  <div className="lp-wallet-success">
                    <div className="lp-wallet-success-icon">✓</div>
                    <strong>Check your email</strong>
                    <p>We sent a magic link to <em>{email}</em>. Click it to create your wallet and start earning.</p>
                  </div>
                ) : (
                  <form className="lp-wallet-form" onSubmit={handleConnect}>
                    <p className="lp-wallet-form-label">Get started with your email — wallet created automatically.</p>
                    <input
                      className="lp-wallet-input"
                      type="email"
                      placeholder="you@example.com"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      required
                    />
                    {errMsg && <div className="lp-wallet-error">{errMsg}</div>}
                    <button type="submit" className="lp-wallet-btn" disabled={status === 'loading'}>
                      {status === 'loading' ? 'Connecting…' : '✦ Connect Stellar Wallet'}
                    </button>
                    <div className="lp-wallet-or">or</div>
                    <button type="button" className="lp-wallet-btn-ghost" onClick={onSignup}>
                      Create full account →
                    </button>
                  </form>
                )}
              </div>
            </div>
          </Reveal>
        </div>
      </div>
    </section>
  )
}

export function LandingPage() {
  const navigate = useNavigate()

  return (
    <div className="lp-root">

      {/* ── Nav ── */}
      <nav className="lp-nav">
        <div className="lp-nav-logo">
          <img src="/app-icon.png" alt="EchoMirror" className="lp-nav-icon" />
          <span className="lp-nav-wordmark">EchoMirror</span>
        </div>
        <div className="lp-nav-links">
          <a href="#features" className="lp-nav-link">Features</a>
          <a href="#global" className="lp-nav-link">Global Mirror</a>
          <a href="#wallet" className="lp-nav-link">Wallet</a>
          <Link to="/login" className="lp-nav-link">Sign in</Link>
        </div>
        <button className="lp-btn-solid" onClick={() => navigate('/signup')}>
          Get started free
        </button>
      </nav>

      {/* ── Hero — two column ── */}
      <section className="lp-hero">
        <div className="lp-video-wrap">
          <video className="lp-video-bg" autoPlay muted loop playsInline
            poster="https://images.pexels.com/photos/3759079/pexels-photo-3759079.jpeg?auto=compress&cs=tinysrgb&w=1920">
            <source src="https://videos.pexels.com/video-files/3571264/3571264-uhd_2560_1440_25fps.mp4" type="video/mp4" />
          </video>
          <div className="lp-video-overlay" />
        </div>

        <div className="lp-hero-inner">
          {/* Left: copy */}
          <div className="lp-hero-copy">
            <div className="lp-hero-eyebrow">
              <span className="lp-eyebrow-pip" />
              Wellbeing, amplified by AI
            </div>

            <h1 className="lp-hero-title">
              Your mind,<br />
              <em>reflected</em><br />
              back to you.
            </h1>

            <p className="lp-hero-sub">
              Track moods, decode patterns, earn rewards.
              A space that listens as carefully as you listen to yourself.
            </p>

            <div className="lp-hero-actions">
              <button className="lp-cta-primary" onClick={() => navigate('/signup')}>
                Start for free <span className="lp-cta-arrow">→</span>
              </button>
              <Link to="/login" className="lp-cta-ghost">Sign in</Link>
            </div>

            <div className="lp-hero-social-proof">
              <div className="lp-avatar-stack">
                {['#1463ff','#0a8a5b','#7c3aed','#e67a00'].map((c, i) => (
                  <div key={i} className="lp-avatar" style={{ background: c, zIndex: 4 - i }} />
                ))}
              </div>
              <span>Join <strong>2,400+</strong> people tracking their wellbeing</span>
            </div>
          </div>

          {/* Right: app mockup */}
          <div className="lp-hero-mockup">
            <img src="/phone-mockup.png" alt="EchoMirror app" className="lp-phone-img" />
            <div className="lp-float-chip lp-float-chip--1">
              <span className="lp-float-pip" style={{ background: '#0a8a5b' }} />
              Feeling calm today
            </div>
            <div className="lp-float-chip lp-float-chip--2">
              🌍 Lagos is feeling motivated
            </div>
          </div>
        </div>

        {/* Scroll cue */}
        <div className="lp-scroll-cue">
          <div className="lp-scroll-line" />
        </div>
      </section>

      {/* ── Features ── */}
      <section className="lp-section lp-features" id="features">
        <div className="lp-section-inner">
          <Reveal>
            <div className="lp-section-eyebrow">What EchoMirror does</div>
            <h2 className="lp-section-title">Every tool you need<br />to understand yourself.</h2>
            <p className="lp-section-sub">
              Built around mood science, habit formation, and the kind of reflection that actually changes how you feel.
            </p>
          </Reveal>

          <div className="lp-features-grid">
            {features.map((f, i) => (
              <Reveal key={f.title} delay={(i % 2) + 1 as 1 | 2}>
                <div className="lp-feature">
                  <div className="lp-feature-icon" style={{ background: f.bg }}>{f.icon}</div>
                  <div className="lp-feature-title">{f.title}</div>
                  <div className="lp-feature-desc">{f.desc}</div>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* ── Health Awareness Video ── */}
      <section className="lp-section lp-awareness-section">
        <div className="lp-section-inner">
          <Reveal>
            <div className="lp-section-eyebrow" style={{ color: '#0a8a5b' }}>Mental Health Matters</div>
            <h2 className="lp-section-title">Understanding your<br />mental wellbeing.</h2>
            <p className="lp-section-sub">
              Mental health is as real as physical health. EchoMirror gives you the tools to track, understand, and improve yours — every single day.
            </p>
          </Reveal>

          <div className="lp-awareness-body">
            <Reveal delay={1}>
              <div className="lp-awareness-stats">
                {wellnessStats.map((s) => (
                  <div key={s.value} className="lp-awareness-stat">
                    <div className="lp-awareness-stat-value">{s.value}</div>
                    <div className="lp-awareness-stat-label">{s.label}</div>
                  </div>
                ))}
              </div>
            </Reveal>

            <Reveal delay={2}>
              <div className="lp-awareness-video-wrap">
                <div className="lp-awareness-video-badge">Health Awareness</div>
                <video
                  className="lp-awareness-video"
                  autoPlay
                  muted
                  loop
                  playsInline
                  poster="https://images.pexels.com/photos/3822622/pexels-photo-3822622.jpeg?auto=compress&cs=tinysrgb&w=800"
                >
                  <source src="https://videos.pexels.com/video-files/3209828/3209828-uhd_2560_1440_25fps.mp4" type="video/mp4" />
                </video>
                <div className="lp-awareness-video-caption">
                  <span>🌿</span> Your mental health journey starts with awareness
                </div>
              </div>
            </Reveal>
          </div>
        </div>
      </section>

      {/* ── Global Mirror ── */}
      <section className="lp-section lp-globe-section" id="global">
        <div className="lp-section-inner">
          <div className="lp-globe-inner">
            <Reveal>
              <div className="lp-section-eyebrow">Global Mirror</div>
              <h2 className="lp-section-title">You're never the<br />only one feeling this.</h2>
              <p className="lp-section-sub">
                Real-time mood data from users worldwide. Watch the global emotional pulse shift with the day, seasons, and world events.
              </p>
              <div style={{ marginTop: '2rem' }}>
                <div className="lp-ticker-wrap">
                  <div className="lp-ticker">
                    {[...tickerItems, ...tickerItems].map((item, i) => (
                      <div key={i} className="lp-ticker-item">
                        <span className="lp-ticker-flag">{item.flag}</span>
                        <span className="lp-ticker-mood" style={{ background: item.color }} />
                        <span>{item.city} — <strong>{item.mood}</strong></span>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </Reveal>

            <Reveal delay={2}>
              <div className="lp-globe-visual">
                <div className="lp-rings">
                  <div className="lp-ring" /><div className="lp-ring" />
                  <div className="lp-ring" /><div className="lp-ring" />
                  <div className="lp-ring-center">🌍</div>
                  {[
                    { top: '12%', left: '58%', color: '#0a8a5b' },
                    { top: '38%', left: '92%', color: '#1463ff' },
                    { top: '72%', left: '75%', color: '#e67a00' },
                    { top: '80%', left: '25%', color: '#bb2d3b' },
                    { top: '45%', left: '5%',  color: '#8b5cf6' },
                    { top: '15%', left: '28%', color: '#0a8a5b' },
                  ].map((dot, i) => (
                    <div key={i} className="lp-orbit-dot" style={{
                      top: dot.top, left: dot.left, background: dot.color, color: dot.color,
                      animation: `ring-pulse ${3 + i * 0.7}s ease-in-out infinite`,
                      animationDelay: `${i * 0.5}s`,
                    }} />
                  ))}
                </div>
              </div>
            </Reveal>
          </div>
        </div>
      </section>

      {/* ── Stellar explainer ── */}
      <section className="lp-section lp-stellar-section">
        <div className="lp-section-inner">
          <Reveal>
            <div className="lp-section-eyebrow" style={{ color: '#7dd3fc' }}>Powered by Stellar</div>
            <h2 className="lp-section-title" style={{ color: 'white' }}>
              Money that moves<br />
              <em style={{ fontStyle: 'italic', color: '#7dd3fc' }}>with your mood.</em>
            </h2>
            <p className="lp-section-sub" style={{ color: 'rgba(255,255,255,0.5)' }}>
              EchoMirror uses the Stellar blockchain to make sending value as easy as sending a message.
              No banks. No fees. Just people supporting people.
            </p>
          </Reveal>

          <div className="lp-stellar-steps">
            {[
              {
                step: '01',
                icon: '📓',
                title: 'Log your mood daily',
                body: 'Every entry you submit earns ECHO tokens — the native currency of EchoMirror, settled on Stellar Testnet in seconds.',
              },
              {
                step: '02',
                icon: '🎁',
                title: 'Gift ECHO to a friend',
                body: 'See someone grinding through a tough week? Send them ECHO directly from your wallet. It lands in their account instantly, anywhere in the world.',
              },
              {
                step: '03',
                icon: '🔥',
                title: 'Reward habit streaks',
                body: 'Set a challenge with a friend — whoever keeps their streak alive gets the ECHO pot. Accountability just got a prize.',
              },
              {
                step: '04',
                icon: '🌍',
                title: 'No borders, no banks',
                body: 'Stellar settles transactions in 3–5 seconds with near-zero fees. Lagos to London, Mumbai to New York — ECHO travels instantly.',
              },
            ].map((s, i) => (
              <Reveal key={s.step} delay={(i % 2 + 1) as 1 | 2}>
                <div className="lp-stellar-step">
                  <div className="lp-stellar-step-num">{s.step}</div>
                  <div className="lp-stellar-step-icon">{s.icon}</div>
                  <div className="lp-stellar-step-title">{s.title}</div>
                  <div className="lp-stellar-step-body">{s.body}</div>
                </div>
              </Reveal>
            ))}
          </div>

          <Reveal>
            <div className="lp-stellar-quote">
              <div className="lp-stellar-quote-mark">"</div>
              <p>Stellar makes it possible to send ECHO to a friend across the world in the same time it takes to write them a message. That's the future of emotional support.</p>
            </div>
          </Reveal>
        </div>
      </section>

      {/* ── Wallet Connect ── */}
      <WalletConnectSection onSignup={() => navigate('/signup')} />

      {/* ── CTA ── */}
      <section className="lp-section lp-cta-section">
        <div className="lp-section-inner">
          <Reveal>
            <h2 className="lp-section-title" style={{ color: 'white' }}>Your reflection<br />is waiting.</h2>
            <p className="lp-section-sub" style={{ color: 'rgba(255,255,255,0.5)', margin: '1rem auto 0' }}>
              Free to start. No credit card. No noise.
            </p>
            <div><button className="lp-cta-big" onClick={() => navigate('/signup')}>Start your journey →</button></div>
            <p className="lp-signin-note">Already a member? <Link to="/login">Sign in here</Link></p>
          </Reveal>
        </div>
      </section>

      {/* ── Footer ── */}
      <footer className="lp-footer">
        <span className="lp-footer-logo">EchoMirror</span>
        <span className="lp-footer-copy">© 2025 EchoMirror. All rights reserved.</span>
      </footer>
    </div>
  )
}
