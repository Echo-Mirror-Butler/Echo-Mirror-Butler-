import { useEffect, useRef, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '../../lib/supabase'
import { useTheme } from '../../lib/use-theme'
import './landing-page.css'

const features = [
  {
    icon: '🧠',
    bg: 'linear-gradient(135deg,#dbeafe,#eff6ff)',
    accent: '#1463ff',
    title: 'AI Mood Insights',
    desc: 'Your AI companion surfaces personalised reflections shaped by your history — not generic advice.',
    stat: '94% accuracy',
  },
  {
    icon: '🌍',
    bg: 'linear-gradient(135deg,#d6f8ef,#ecfdf5)',
    accent: '#0a8a5b',
    title: 'Global Mirror',
    desc: 'See how your emotional state compares with thousands worldwide, in real time.',
    stat: '180+ countries',
  },
  {
    icon: '📓',
    bg: 'linear-gradient(135deg,#ede9fe,#f5f3ff)',
    accent: '#7c3aed',
    title: 'Habit & Mood Logs',
    desc: 'Log what you feel. Over time, patterns emerge you\'d never catch in the moment.',
    stat: '2 min/day',
  },
  {
    icon: '✦',
    bg: 'linear-gradient(135deg,#fef3c7,#fffbeb)',
    accent: '#d97706',
    title: 'ECHO Wallet',
    desc: 'Earn ECHO tokens on Stellar just by showing up. Consistency has real value here.',
    stat: 'Real Stellar tokens',
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
  { value: '1 in 4', label: 'people experience a mental health condition each year', color: '#1463ff' },
  { value: '60%',    label: 'never seek help due to stigma or lack of access', color: '#bb2d3b' },
  { value: '40%',    label: 'mood improvement from consistent journalling', color: '#0a8a5b' },
  { value: '3×',     label: 'more likely to sustain habits when tracking mood daily', color: '#7c3aed' },
]

function useReveal() {
  const ref = useRef<HTMLDivElement>(null)
  useEffect(() => {
    const el = ref.current
    if (!el) return
    const observer = new IntersectionObserver(
      ([entry]) => { if (entry.isIntersecting) { el.classList.add('is-visible'); observer.disconnect() } },
      { threshold: 0.08 },
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

interface GithubContributor {
  login: string
  avatar_url: string
  html_url: string
  contributions: number
}

function ContributorsSection() {
  const { data, isLoading, isError } = useQuery<GithubContributor[]>({
    queryKey: ['github-contributors'],
    queryFn: async () => {
      const res = await fetch(
        'https://api.github.com/repos/Echo-Mirror-Butler/Echo-Mirror-Butler-/contributors?per_page=100&anon=false',
        { headers: { Accept: 'application/vnd.github+json' } },
      )
      if (!res.ok) throw new Error('Failed to fetch contributors')
      return res.json()
    },
    staleTime: 1000 * 60 * 10,
    gcTime: 1000 * 60 * 30,
  })

  return (
    <section className="lp-section lp-contributors-section" id="contributors">
      <div className="lp-section-inner">
        <Reveal>
          <div className="lp-section-eyebrow" style={{ color: '#7c3aed' }}>Open Source</div>
          <h2 className="lp-section-title">Built by the community,<br />for the community.</h2>
          <p className="lp-section-sub">
            EchoMirror is proudly open source on Stellar Wave. Every contributor below
            has shipped real code that people use every day.
          </p>
        </Reveal>

        {isLoading && (
          <div className="lp-contributors-skeleton">
            {Array.from({ length: 12 }).map((_, i) => (
              <div key={i} className="lp-contributor-skel">
                <div className="lp-skel-avatar" style={{ animationDelay: `${i * 0.08}s` }} />
                <div className="lp-skel-name" style={{ animationDelay: `${i * 0.08}s` }} />
              </div>
            ))}
          </div>
        )}

        {isError && (
          <p style={{ marginTop: '2rem', fontSize: '0.85rem', color: 'var(--lp-ink-30)', textAlign: 'center' }}>
            Could not load contributors right now.
          </p>
        )}

        {data && (
          <div className="lp-contributors-grid">
            {data.map((c) => (
              <a
                key={c.login}
                href={c.html_url}
                target="_blank"
                rel="noopener noreferrer"
                className="lp-contributor"
                title={`${c.login} — ${c.contributions} commit${c.contributions !== 1 ? 's' : ''}`}
              >
                <img
                  src={c.avatar_url}
                  alt={c.login}
                  className="lp-contributor-avatar"
                  loading="lazy"
                />
                <span className="lp-contributor-name">{c.login}</span>
                <span className="lp-contributor-commits">{c.contributions} commit{c.contributions !== 1 ? 's' : ''}</span>
              </a>
            ))}
          </div>
        )}

        <div style={{ textAlign: 'center' }}>
          <a
            href="https://github.com/Echo-Mirror-Butler/Echo-Mirror-Butler-"
            target="_blank"
            rel="noopener noreferrer"
            className="lp-contributors-gh-link"
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
              <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0 0 24 12c0-6.63-5.37-12-12-12z" />
            </svg>
            View all contributors on GitHub
          </a>
        </div>
      </div>
    </section>
  )
}

function WalletConnectSection({ onSignup }: { onSignup: () => void }) {
  const [email, setEmail] = useState('')
  const [status, setStatus] = useState<'idle' | 'loading' | 'done' | 'error'>('idle')
  const [errMsg, setErrMsg] = useState('')

  const handleConnect = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!email.includes('@')) { setErrMsg('Enter a valid email'); return }
    setStatus('loading'); setErrMsg('')
    const { error } = await supabase.auth.signInWithOtp({ email, options: { shouldCreateUser: true } })
    if (error) { setStatus('error'); setErrMsg(error.message) } else { setStatus('done') }
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
                Connect your Stellar wallet and start earning ECHO tokens for every mood log, streak, and insight you unlock. Consistency has currency here.
              </p>
              <div className="lp-wallet-perks">
                {[
                  { icon: '🔥', title: 'Streak rewards',  desc: 'Log 7 days straight, earn bonus ECHO' },
                  { icon: '✦',  title: 'Stellar native',  desc: 'Real tokens on the Stellar blockchain' },
                  { icon: '🎁', title: 'Send to friends', desc: 'Gift ECHO to people who inspire you' },
                  { icon: '🔒', title: 'Non-custodial',   desc: 'Your keys, your tokens, always' },
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
                    <input className="lp-wallet-input" type="email" placeholder="you@example.com"
                      value={email} onChange={(e) => setEmail(e.target.value)} required />
                    {errMsg && <div className="lp-wallet-error">{errMsg}</div>}
                    <button type="submit" className="lp-wallet-btn" disabled={status === 'loading'}>
                      {status === 'loading' ? 'Connecting…' : '✦ Connect Stellar Wallet'}
                    </button>
                    <div className="lp-wallet-or">or</div>
                    <button type="button" className="lp-wallet-btn-ghost" onClick={onSignup}>Create full account →</button>
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
  const { resolvedTheme } = useTheme()
  const [isOverDarkSection, setIsOverDarkSection] = useState(true)
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)

  const closeMobileMenu = () => setMobileMenuOpen(false)

  useEffect(() => {
    if (!mobileMenuOpen) return
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') closeMobileMenu()
    }
    window.addEventListener('keydown', handleKey)
    return () => window.removeEventListener('keydown', handleKey)
  }, [mobileMenuOpen])

  useEffect(() => {
    if (resolvedTheme !== 'light') {
      setIsOverDarkSection(true)
      return
    }

    const darkSections = Array.from(
      document.querySelectorAll<HTMLElement>(
        '.lp-hero, .lp-stellar-section, .lp-wallet-section, .lp-cta-section, .lp-footer',
      ),
    )
    const navHeight = 64
    let frameId: number | null = null

    const checkNavBackground = () => {
      frameId = null
      const isOverDark = darkSections.some((section) => {
        const rect = section.getBoundingClientRect()
        return rect.top < navHeight && rect.bottom > 0
      })
      setIsOverDarkSection(isOverDark)
    }

    const scheduleCheck = () => {
      if (frameId !== null) return
      frameId = window.requestAnimationFrame(checkNavBackground)
    }

    checkNavBackground()
    window.addEventListener('scroll', scheduleCheck, { passive: true })
    window.addEventListener('resize', scheduleCheck)

    return () => {
      window.removeEventListener('scroll', scheduleCheck)
      window.removeEventListener('resize', scheduleCheck)
      if (frameId !== null) window.cancelAnimationFrame(frameId)
    }
  }, [resolvedTheme])

  return (
    <div className="lp-root">

      {/* ── Nav ── */}
      <nav className={`lp-nav ${isOverDarkSection ? 'lp-nav--dark' : 'lp-nav--light'}`}>
        <div className="lp-nav-logo">
          <img src="/app-icon.png" alt="EchoMirror" className="lp-nav-icon" />
          <span className="lp-nav-wordmark">EchoMirror</span>
        </div>
        <div className="lp-nav-links">
          <a href="#features" className="lp-nav-link">Features</a>
          <a href="#global" className="lp-nav-link">Global Mirror</a>
          <a href="#wallet" className="lp-nav-link">Wallet</a>
          <a href="#contributors" className="lp-nav-link">Contributors</a>
          <Link to="/login" className="lp-nav-link">Sign in</Link>
        </div>
        <button className="lp-btn-solid" onClick={() => navigate('/signup')}>Get started free</button>
        <button
          className={`lp-hamburger ${isOverDarkSection ? 'lp-hamburger--dark' : 'lp-hamburger--light'}`}
          onClick={() => setMobileMenuOpen((v) => !v)}
          aria-label={mobileMenuOpen ? 'Close menu' : 'Open menu'}
          aria-expanded={mobileMenuOpen}
        >
          {mobileMenuOpen ? '✕' : '☰'}
        </button>
      </nav>

      {/* ── Mobile menu ── */}
      <div
        className={`lp-mobile-backdrop ${mobileMenuOpen ? 'open' : ''}`}
        onClick={closeMobileMenu}
      />
      <div className={`lp-mobile-menu ${mobileMenuOpen ? 'open' : ''} ${isOverDarkSection ? 'lp-mobile-menu--dark' : 'lp-mobile-menu--light'}`}>
        <div className="lp-mobile-menu-inner">
          <button className="lp-mobile-menu-close" onClick={closeMobileMenu} aria-label="Close menu">
            ✕
          </button>
          <div className="lp-mobile-menu-links">
            <a href="#features" className="lp-mobile-menu-link" onClick={closeMobileMenu}>Features</a>
            <a href="#global" className="lp-mobile-menu-link" onClick={closeMobileMenu}>Global Mirror</a>
            <a href="#wallet" className="lp-mobile-menu-link" onClick={closeMobileMenu}>Wallet</a>
            <a href="#contributors" className="lp-mobile-menu-link" onClick={closeMobileMenu}>Contributors</a>
            <Link to="/login" className="lp-mobile-menu-link" onClick={closeMobileMenu}>Sign in</Link>
          </div>
          <button className="lp-mobile-menu-cta" onClick={() => { closeMobileMenu(); navigate('/signup') }}>
            Get started free
          </button>
        </div>
      </div>

      {/* ── Hero ── */}
      <section className="lp-hero">
        <div className="lp-video-wrap">
          <video className="lp-video-bg" autoPlay muted loop playsInline
            poster="https://images.pexels.com/photos/3759079/pexels-photo-3759079.jpeg?auto=compress&cs=tinysrgb&w=1920">
            <source src="https://videos.pexels.com/video-files/3571264/3571264-uhd_2560_1440_25fps.mp4" type="video/mp4" />
          </video>
          <div className="lp-video-overlay" />
        </div>

        <div className="lp-hero-inner">
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
              Track moods, decode patterns, earn rewards on Stellar.
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

          <div className="lp-hero-mockup">
            <div className="lp-hero-mockup-glow" />
            <img src="/phone-mockup.png" alt="EchoMirror app" className="lp-phone-img" />
            <div className="lp-float-chip lp-float-chip--1">
              <span className="lp-float-pip" style={{ background: '#0a8a5b' }} />
              Feeling calm today
            </div>
            <div className="lp-float-chip lp-float-chip--2">
              🌍 New York is feeling motivated
            </div>
            <div className="lp-float-chip lp-float-chip--3">
              ✦ +5 ECHO earned today
            </div>
          </div>
        </div>

        <div className="lp-scroll-cue"><div className="lp-scroll-line" /></div>
      </section>

      {/* ── Logos / trust bar ── */}
      <div className="lp-trust-bar">
        <span className="lp-trust-label">Built on</span>
        {['Stellar', 'Supabase', 'Flutter', 'React'].map((t) => (
          <span key={t} className="lp-trust-item">{t}</span>
        ))}
      </div>

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
                  <div className="lp-feature-top" style={{ background: f.bg }}>
                    <div className="lp-feature-icon-wrap">{f.icon}</div>
                    <div className="lp-feature-stat" style={{ color: f.accent }}>{f.stat}</div>
                  </div>
                  <div className="lp-feature-body">
                    <div className="lp-feature-title">{f.title}</div>
                    <div className="lp-feature-desc">{f.desc}</div>
                  </div>
                  <div className="lp-feature-bar" style={{ background: f.accent }} />
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* ── Health Awareness ── */}
      <section className="lp-section lp-awareness-section">
        <div className="lp-section-inner">
          <Reveal>
            <div className="lp-section-eyebrow" style={{ color: '#0a8a5b' }}>Mental Health Matters</div>
            <h2 className="lp-section-title">The data is clear.<br />Your mind needs care too.</h2>
            <p className="lp-section-sub">
              Mental health is as real as physical health. EchoMirror gives you the tools to track, understand, and improve yours — every single day.
            </p>
          </Reveal>

          <div className="lp-awareness-body">
            <Reveal delay={1}>
              <div className="lp-awareness-stats">
                {wellnessStats.map((s) => (
                  <div key={s.value} className="lp-awareness-stat">
                    <div className="lp-awareness-stat-bar" style={{ background: s.color }} />
                    <div className="lp-awareness-stat-value" style={{ color: s.color }}>{s.value}</div>
                    <div className="lp-awareness-stat-label">{s.label}</div>
                  </div>
                ))}
              </div>
            </Reveal>

            <Reveal delay={2}>
              <div className="lp-awareness-video-wrap">
                <div className="lp-awareness-video-badge">Health Awareness</div>
                <video className="lp-awareness-video" autoPlay muted loop playsInline
                  poster="https://images.pexels.com/photos/3822622/pexels-photo-3822622.jpeg?auto=compress&cs=tinysrgb&w=800">
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

      {/* ── How it works ── */}
      <section className="lp-section lp-how-section">
        <div className="lp-section-inner">
          <Reveal>
            <div className="lp-section-eyebrow">How it works</div>
            <h2 className="lp-section-title">Three steps to<br />a clearer mind.</h2>
          </Reveal>
          <div className="lp-how-steps">
            {[
              { n: '1', title: 'Log how you feel', body: 'Takes 60 seconds. Rate your mood, note your habits, add a thought. That\'s it.', color: '#1463ff' },
              { n: '2', title: 'AI finds the patterns', body: 'EchoMirror\'s AI surfaces what your brain misses — the links between sleep, mood, habits, and time.', color: '#0a8a5b' },
              { n: '3', title: 'Earn & grow', body: 'Consistency earns ECHO tokens on Stellar. Share them, gift them, or hold them as proof you showed up.', color: '#7c3aed' },
            ].map((s, i) => (
              <Reveal key={s.n} delay={(i + 1) as 1 | 2}>
                <div className="lp-how-step">
                  <div className="lp-how-num" style={{ color: s.color, borderColor: s.color }}>{s.n}</div>
                  <div className="lp-how-connector" style={{ background: s.color }} />
                  <div className="lp-how-title">{s.title}</div>
                  <div className="lp-how-body">{s.body}</div>
                </div>
              </Reveal>
            ))}
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
              EchoMirror uses the Stellar blockchain to make sending value as easy as sending a message. No banks. No fees. Just people supporting people.
            </p>
          </Reveal>

          <div className="lp-stellar-steps">
            {[
              { step: '01', icon: '📓', title: 'Log your mood daily', body: 'Every entry earns ECHO tokens — the native currency of EchoMirror, settled on Stellar in seconds.' },
              { step: '02', icon: '🎁', title: 'Gift ECHO to a friend', body: 'Someone grinding through a tough week? Send them ECHO directly. It lands instantly, anywhere in the world.' },
              { step: '03', icon: '🔥', title: 'Reward habit streaks', body: 'Set a challenge with a friend — whoever keeps their streak alive gets the ECHO pot. Accountability just got a prize.' },
              { step: '04', icon: '🌍', title: 'No borders, no banks', body: 'Stellar settles in 3–5 seconds with near-zero fees. Lagos to London, Mumbai to New York — ECHO travels instantly.' },
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

      {/* ── Testimonial ── */}
      <section className="lp-section lp-testimonials-section">
        <div className="lp-section-inner">
          <Reveal>
            <div className="lp-section-eyebrow">From the community</div>
            <h2 className="lp-section-title">People are already<br />feeling the difference.</h2>
          </Reveal>
          <div className="lp-testimonials-grid">
            {[
              { quote: 'I never realised how much my sleep was wrecking my mood until EchoMirror showed me the pattern. Two weeks of data changed my whole routine.', name: 'Amara O.', loc: 'Lagos', color: '#0a8a5b' },
              { quote: 'Gifting ECHO to my friend after she hit her 30-day streak was genuinely one of the most wholesome things I\'ve done on a phone.', name: 'Luca M.', loc: 'Berlin', color: '#1463ff' },
              { quote: 'It\'s the first app that actually made me want to check in with myself every day. The AI insights feel like talking to a very calm, wise friend.', name: 'Priya S.', loc: 'Mumbai', color: '#7c3aed' },
            ].map((t, i) => (
              <Reveal key={i} delay={(i % 2 + 1) as 1 | 2}>
                <div className="lp-testimonial">
                  <div className="lp-testimonial-quote">{t.quote}</div>
                  <div className="lp-testimonial-author">
                    <div className="lp-testimonial-avatar" style={{ background: t.color }}>
                      {t.name[0]}
                    </div>
                    <div>
                      <div className="lp-testimonial-name">{t.name}</div>
                      <div className="lp-testimonial-loc">{t.loc}</div>
                    </div>
                  </div>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* ── Contributors ── */}
      <ContributorsSection />

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
        <div className="lp-footer-left">
          <span className="lp-footer-logo">EchoMirror</span>
          <span className="lp-footer-tagline">Your mind, reflected back to you.</span>
        </div>
        <div className="lp-footer-links">
          <a href="#features">Features</a>
          <a href="#global">Global Mirror</a>
          <a href="#wallet">Wallet</a>
          <Link to="/login">Sign in</Link>
        </div>
        <span className="lp-footer-copy">© 2025 EchoMirror. All rights reserved.</span>
      </footer>
    </div>
  )
}
