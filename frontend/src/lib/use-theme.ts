/**
 * useTheme — dark / light / system theme hook  (#263)
 *
 * Persists the chosen theme in localStorage under 'echo-theme'.
 * Applies data-theme="dark" or data-theme="light" on <html>.
 * Falls back to the OS preference when theme is 'system'.
 */
import { useCallback, useEffect, useState } from 'react'

export type Theme = 'light' | 'dark' | 'system'

const STORAGE_KEY = 'echo-theme'

export function resolveApplied(theme: Theme): 'light' | 'dark' {
  if (theme === 'system') {
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
  }
  return theme
}

function applyTheme(theme: Theme) {
  const applied = resolveApplied(theme)
  if (applied === 'dark') {
    document.documentElement.setAttribute('data-theme', 'dark')
  } else {
    document.documentElement.removeAttribute('data-theme')
  }
}

export function useTheme() {
  const [theme, setThemeState] = useState<Theme>(() => {
    try {
      const stored = localStorage.getItem(STORAGE_KEY)
      if (stored === 'light' || stored === 'dark' || stored === 'system') return stored
    } catch {
      // ignore (SSR / private browsing)
    }
    return 'system'
  })

  // Apply on mount and whenever theme changes
  useEffect(() => {
    applyTheme(theme)
  }, [theme])

  // Track OS preference changes when in 'system' mode
  useEffect(() => {
    if (theme !== 'system') return
    const mq = window.matchMedia('(prefers-color-scheme: dark)')
    const handler = () => applyTheme('system')
    mq.addEventListener('change', handler)
    return () => mq.removeEventListener('change', handler)
  }, [theme])

  const setTheme = useCallback((next: Theme) => {
    try {
      localStorage.setItem(STORAGE_KEY, next)
    } catch {
      // ignore
    }
    setThemeState(next)
  }, [])

  const resolvedTheme = resolveApplied(theme)

  return { theme, setTheme, resolvedTheme }
}
