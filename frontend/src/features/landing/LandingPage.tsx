import { useEffect, useRef } from 'react'
import { Link, useNavigate } from 'react-router-dom'
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

            {/* Floating mood chip outside phone */}
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
