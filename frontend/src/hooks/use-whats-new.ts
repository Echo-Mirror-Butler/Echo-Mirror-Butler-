import { useEffect, useState } from 'react'
import changelog from '../data/changelog.json'

const STORAGE_KEY = 'echo-last-seen-version'

export type ChangelogEntry = {
  version: string
  date: string
  items: string[]
}

// The app version is defined by the top (most recent) changelog entry —
// bump it there to trigger the what's-new modal on next deploy.
export const CURRENT_VERSION: string = (changelog as ChangelogEntry[])[0]?.version ?? '0.0.0'

export function getLatestChangelogEntry(): ChangelogEntry | undefined {
  return (changelog as ChangelogEntry[])[0]
}

/**
 * Shows the what's-new modal once per deployed version bump: if the
 * last-seen version stored in localStorage differs from the running app
 * version, the modal opens. First-ever visit just records the version
 * silently — there's nothing to compare an "update" against yet.
 */
export function useWhatsNew() {
  const [isOpen, setIsOpen] = useState(false)

  useEffect(() => {
    let lastSeen: string | null = null
    try {
      lastSeen = window.localStorage.getItem(STORAGE_KEY)
    } catch {
      return
    }

    if (lastSeen === null) {
      try {
        window.localStorage.setItem(STORAGE_KEY, CURRENT_VERSION)
      } catch {
        /* localStorage unavailable — nothing to persist */
      }
      return
    }

    if (lastSeen !== CURRENT_VERSION) {
      setIsOpen(true)
    }
  }, [])

  const dismiss = () => {
    setIsOpen(false)
    try {
      window.localStorage.setItem(STORAGE_KEY, CURRENT_VERSION)
    } catch {
      /* localStorage unavailable — modal will just show again next visit */
    }
  }

  return { isOpen, dismiss }
}
