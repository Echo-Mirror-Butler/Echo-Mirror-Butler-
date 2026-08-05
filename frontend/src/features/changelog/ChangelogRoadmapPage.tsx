import { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import { useTheme } from '../../lib/use-theme'
import changelogRaw from '../../../../CHANGELOG.md?raw'

interface ChangelogEntry {
  version: string
  date: string
  sections: {
    title: string
    items: string[]
  }[]
}

function parseChangelog(markdown: string): ChangelogEntry[] {
  const entries: ChangelogEntry[] = []
  const lines = markdown.split('\n')
  let currentEntry: ChangelogEntry | null = null
  let currentSection: { title: string; items: string[] } | null = null

  for (let line of lines) {
    line = line.trim()
    if (!line) continue

    // Match Version: e.g. ## [1.2.0] - 2026-07-27
    const versionMatch = line.match(/^##\s+\[?([0-9.]+)\]?\s*-\s*([0-9-]+)/)
    if (versionMatch) {
      if (currentEntry) {
        if (currentSection) currentEntry.sections.push(currentSection)
        entries.push(currentEntry)
      }
      currentEntry = {
        version: versionMatch[1],
        date: versionMatch[2],
        sections: [],
      }
      currentSection = null
      continue
    }

    // Match Section Title: e.g. ### Added
    const sectionMatch = line.match(/^###\s+(.+)/)
    if (sectionMatch && currentEntry) {
      if (currentSection) {
        currentEntry.sections.push(currentSection)
      }
      currentSection = {
        title: sectionMatch[1],
        items: [],
      }
      continue
    }

    // Match Bullet Point: e.g. - Publicly accessible...
    const bulletMatch = line.match(/^[-*+]\s+(.+)/)
    if (bulletMatch && currentSection) {
      currentSection.items.push(bulletMatch[1])
    }
  }

  if (currentEntry) {
    if (currentSection) currentEntry.sections.push(currentSection)
    entries.push(currentEntry)
  }

  return entries
}

function renderTextWithFormat(text: string) {
  const parts = []
  let remaining = text

  while (remaining.length > 0) {
    const linkMatch = remaining.match(/\[([^\]]+)\]\(([^)]+)\)/)
    const codeMatch = remaining.match(/`([^`]+)`/)

    const linkIdx = linkMatch && linkMatch.index !== undefined ? linkMatch.index : Infinity
    const codeIdx = codeMatch && codeMatch.index !== undefined ? codeMatch.index : Infinity

    if (linkIdx === Infinity && codeIdx === Infinity) {
      parts.push(remaining)
      break
    }

    if (linkIdx < codeIdx) {
      if (linkIdx > 0) {
        parts.push(remaining.substring(0, linkIdx))
      }
      const [full, linkText, linkUrl] = linkMatch!
      parts.push(
        <a
          key={remaining + linkIdx}
          href={linkUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="text-brand hover:underline font-medium dark:text-indigo-400"
        >
          {linkText}
        </a>,
      )
      remaining = remaining.substring(linkIdx + full.length)
    } else {
      if (codeIdx > 0) {
        parts.push(remaining.substring(0, codeIdx))
      }
      const [full, codeText] = codeMatch!
      parts.push(
        <code
          key={remaining + codeIdx}
          className="bg-gray-100 dark:bg-gray-800 px-1.5 py-0.5 rounded text-sm font-mono text-pink-600 dark:text-pink-400 border border-gray-200 dark:border-gray-700"
        >
          {codeText}
        </code>,
      )
      remaining = remaining.substring(codeIdx + full.length)
    }
  }

  return parts.length > 0 ? parts : text
}

export function ChangelogRoadmapPage() {
  useTheme()
  const [activeTab, setActiveTab] = useState<'changelog' | 'roadmap'>('changelog')
  const [changelogData, setChangelogData] = useState<ChangelogEntry[]>([])

  useEffect(() => {
    // Set active tab based on path initially
    if (window.location.pathname.includes('roadmap')) {
      setActiveTab('roadmap')
    } else {
      setActiveTab('changelog')
    }
  }, [])

  useEffect(() => {
    setChangelogData(parseChangelog(changelogRaw))
  }, [])

  const milestones = [
    {
      title: 'Milestone 1: Web Client Polish & Credentials Audit',
      status: 'In Progress',
      statusColor: 'bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-300 border border-amber-200 dark:border-amber-800',
      description: 'Auditing authentication flows, updating Autofill/Autocomplete attributes for password managers, and polishing public pages.',
      issueLink: 'https://github.com/Echo-Mirror-Butler/Echo-Mirror-Butler-/issues',
      milestoneLink: 'https://github.com/Echo-Mirror-Butler/Echo-Mirror-Butler-/milestones',
    },
    {
      title: 'Milestone 2: Non-Custodial Stellar Wallet Integration',
      status: 'Planned',
      statusColor: 'bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-300 border border-blue-200 dark:border-blue-800',
      description: 'Allow users to link external Freighter wallets, receive native ECHO tokens directly, and enable cross-border support tipping.',
      issueLink: 'https://github.com/Echo-Mirror-Butler/Echo-Mirror-Butler-/issues',
      milestoneLink: 'https://github.com/Echo-Mirror-Butler/Echo-Mirror-Butler-/milestones',
    },
    {
      title: 'Milestone 3: AI-Driven Personal Companion Model',
      status: 'Planned',
      statusColor: 'bg-purple-100 text-purple-800 dark:bg-purple-900/30 dark:text-purple-300 border border-purple-200 dark:border-purple-800',
      description: 'Implement a customizable LLM agent structure that surfaces tailored wellbeing tips and processes mental health tracking metrics.',
      issueLink: 'https://github.com/Echo-Mirror-Butler/Echo-Mirror-Butler-/issues',
      milestoneLink: 'https://github.com/Echo-Mirror-Butler/Echo-Mirror-Butler-/milestones',
    },
    {
      title: 'Milestone 4: Native Mobile Client Launch',
      status: 'Planned',
      statusColor: 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300 border border-green-200 dark:border-green-800',
      description: 'Publish companion Flutter mobile applications on Apple App Store & Google Play Store.',
      issueLink: 'https://github.com/Echo-Mirror-Butler/Echo-Mirror-Butler-/issues',
      milestoneLink: 'https://github.com/Echo-Mirror-Butler/Echo-Mirror-Butler-/milestones',
    },
  ]

  return (
    <div className="min-h-screen bg-[var(--bg)] text-[var(--text)] transition-colors duration-300">
      {/* Navigation Header */}
      <nav className="border-b border-[var(--line)] bg-[var(--surface)] sticky top-0 z-50 transition-colors duration-300">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <img src="/app-icon.png" alt="EchoMirror" className="h-8 w-8" />
            <Link to="/" className="text-xl font-bold font-display hover:opacity-90">
              EchoMirror
            </Link>
          </div>
          <div className="flex items-center space-x-4">
            <Link
              to="/"
              className="text-sm font-medium text-[var(--muted)] hover:text-[var(--text)] transition-colors"
            >
              Back to Home
            </Link>
            <Link
              to="/signup"
              className="text-sm font-medium bg-[var(--brand)] hover:bg-[var(--brand-strong)] text-white px-4 py-2 rounded-xl transition-all shadow-sm"
            >
              Get Started
            </Link>
          </div>
        </div>
      </nav>

      {/* Hero Header Banner */}
      <header className="relative overflow-hidden bg-gradient-to-br from-indigo-900 via-slate-900 to-indigo-950 text-white py-16 px-4">
        <div className="absolute inset-0 bg-[radial-gradient(circle_at_30%_30%,rgba(99,102,241,0.15),transparent)] pointer-events-none" />
        <div className="max-w-4xl mx-auto text-center relative z-10">
          <h1 className="text-4xl md:text-5xl font-extrabold tracking-tight mb-4 font-display">
            Changelog & Roadmap
          </h1>
          <p className="text-lg md:text-xl text-slate-300 max-w-2xl mx-auto font-light">
            Stay up to date with the latest features shipped to EchoMirror, explore our future direction, and help shape the project on GitHub.
          </p>

          {/* Tab buttons */}
          <div className="mt-8 inline-flex p-1 bg-white/10 backdrop-blur-md rounded-2xl border border-white/15">
            <button
              onClick={() => {
                setActiveTab('changelog')
                window.history.pushState(null, '', '/changelog')
              }}
              className={`px-6 py-2.5 rounded-xl text-sm font-semibold transition-all duration-200 cursor-pointer ${
                activeTab === 'changelog'
                  ? 'bg-white text-slate-950 shadow-sm'
                  : 'text-white hover:bg-white/5'
              }`}
            >
              Shipped Features
            </button>
            <button
              onClick={() => {
                setActiveTab('roadmap')
                window.history.pushState(null, '', '/roadmap')
              }}
              className={`px-6 py-2.5 rounded-xl text-sm font-semibold transition-all duration-200 cursor-pointer ${
                activeTab === 'roadmap'
                  ? 'bg-white text-slate-950 shadow-sm'
                  : 'text-white hover:bg-white/5'
              }`}
            >
              Future Roadmap
            </button>
          </div>
        </div>
      </header>

      {/* Main Content Area */}
      <main className="max-w-4xl mx-auto px-4 py-12">
        {activeTab === 'changelog' ? (
          <div className="space-y-12">
            {changelogData.length === 0 ? (
              <div className="text-center py-12 text-[var(--muted)]">
                Loading changelog content...
              </div>
            ) : (
              <div className="relative border-l-2 border-[var(--line)] pl-6 ml-4 space-y-12">
                {changelogData.map((entry) => (
                  <div key={entry.version} className="relative">
                    {/* Timeline Node dot */}
                    <div className="absolute -left-[35px] top-1.5 w-6 h-6 rounded-full bg-[var(--brand)] border-4 border-[var(--bg)] flex items-center justify-center shadow-sm" />

                    {/* Version Badge and Date */}
                    <div className="flex flex-wrap items-baseline gap-3 mb-4">
                      <h2 className="text-2xl font-bold tracking-tight">
                        v{entry.version}
                      </h2>
                      <span className="text-sm font-semibold text-[var(--muted)]">
                        Released on {entry.date}
                      </span>
                    </div>

                    {/* Changelog Sections (Added, Fixed, etc.) */}
                    <div className="bg-[var(--surface)] border border-[var(--line)] rounded-2xl p-6 shadow-sm space-y-6">
                      {entry.sections.map((section) => (
                        <div key={section.title} className="space-y-3">
                          <h3 className="text-md font-bold tracking-wide uppercase text-[var(--brand)]">
                            {section.title}
                          </h3>
                          <ul className="list-disc list-inside space-y-2 text-[var(--text)] pl-2">
                            {section.items.map((item, idx) => (
                              <li key={idx} className="leading-relaxed">
                                <span className="ml-1 text-[var(--text)] opacity-90">
                                  {renderTextWithFormat(item)}
                                </span>
                              </li>
                            ))}
                          </ul>
                        </div>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        ) : (
          <div className="space-y-8">
            <div className="bg-[var(--surface)] border border-[var(--line)] rounded-3xl p-8 shadow-sm">
              <h2 className="text-2xl font-bold mb-4 font-display">Development Milestones</h2>
              <p className="text-[var(--muted)] mb-8 leading-relaxed">
                We plan and track our developments transparently using GitHub milestones. Check our active targets below or follow along directly in the repository.
              </p>

              <div className="space-y-6">
                {milestones.map((milestone, idx) => (
                  <div
                    key={idx}
                    className="border border-[var(--line)] rounded-2xl p-6 hover:shadow-md transition-shadow duration-200 bg-[var(--bg)]/30"
                  >
                    <div className="flex flex-wrap items-center justify-between gap-3 mb-3">
                      <h3 className="text-lg font-bold text-[var(--text)] font-display">
                        {milestone.title}
                      </h3>
                      <span className={`px-2.5 py-1 rounded-full text-xs font-semibold ${milestone.statusColor}`}>
                        {milestone.status}
                      </span>
                    </div>
                    <p className="text-[var(--muted)] text-sm leading-relaxed mb-4">
                      {milestone.description}
                    </p>
                    <div className="flex space-x-4">
                      <a
                        href={milestone.milestoneLink}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-xs font-semibold text-[var(--brand)] hover:underline flex items-center space-x-1"
                      >
                        <span>View Milestone</span>
                        <span>↗</span>
                      </a>
                      <a
                        href={milestone.issueLink}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-xs font-semibold text-[var(--muted)] hover:underline flex items-center space-x-1"
                      >
                        <span>Related Issues</span>
                        <span>↗</span>
                      </a>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Contributor CTA Section */}
            <div className="bg-gradient-to-br from-indigo-50 to-purple-50 dark:from-indigo-950/20 dark:to-purple-950/20 border border-indigo-100 dark:border-indigo-900/50 rounded-3xl p-8 shadow-sm text-center">
              <h3 className="text-xl font-bold mb-3 font-display">Want to contribute?</h3>
              <p className="text-[var(--muted)] max-w-xl mx-auto mb-6 text-sm leading-relaxed">
                EchoMirror is fully open-source. We welcome contributions from developers of all backgrounds. Browse our labelled issues to get started.
              </p>
              <div className="flex flex-wrap justify-center gap-4">
                <a
                  href="https://github.com/Echo-Mirror-Butler/Echo-Mirror-Butler-/issues?q=is%3Aopen+is%3Aissue+label%3A%22good+first+issue%22"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="bg-indigo-600 hover:bg-indigo-700 text-white font-semibold px-5 py-2.5 rounded-xl text-sm transition-all"
                >
                  Good First Issues
                </a>
                <a
                  href="https://github.com/Echo-Mirror-Butler/Echo-Mirror-Butler-"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="bg-[var(--surface)] hover:bg-[var(--surface-soft)] text-[var(--text)] border border-[var(--line)] font-semibold px-5 py-2.5 rounded-xl text-sm transition-all"
                >
                  GitHub Repository
                </a>
              </div>
            </div>
          </div>
        )}
      </main>

      {/* Footer */}
      <footer className="border-t border-[var(--line)] bg-[var(--surface)] py-12 mt-12 transition-colors duration-300">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex flex-col md:flex-row items-center justify-between gap-6">
          <div className="flex flex-col items-center md:items-start space-y-1">
            <span className="font-bold text-lg font-display">EchoMirror</span>
            <span className="text-xs text-[var(--muted)]">Your mind, reflected back to you.</span>
          </div>
          <div className="flex space-x-6 text-sm font-semibold text-[var(--muted)]">
            <Link to="/" className="hover:text-[var(--text)] transition-colors">
              Features
            </Link>
            <a
              href="https://github.com/Echo-Mirror-Butler/Echo-Mirror-Butler-"
              target="_blank"
              rel="noopener noreferrer"
              className="hover:text-[var(--text)] transition-colors"
            >
              GitHub
            </a>
          </div>
          <span className="text-xs text-[var(--muted)]">
            © 2026 EchoMirror. All rights reserved.
          </span>
        </div>
      </footer>
    </div>
  )
}
