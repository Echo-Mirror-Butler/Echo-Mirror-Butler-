import { renderHook, act } from '@testing-library/react'
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { useTheme } from './use-theme'

// Mock localStorage
const localStorageMock = (() => {
  let store: Record<string, string> = {}
  return {
    getItem: vi.fn((key: string) => store[key] || null),
    setItem: vi.fn((key: string, value: string) => {
      store[key] = value
    }),
    removeItem: vi.fn((key: string) => {
      delete store[key]
    }),
    clear: vi.fn(() => {
      store = {}
    }),
  }
})()

Object.defineProperty(window, 'localStorage', {
  value: localStorageMock,
})

// Mock matchMedia
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: vi.fn().mockImplementation((query) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(), // deprecated
    removeListener: vi.fn(), // deprecated
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  })),
})

describe('useTheme', () => {
  beforeEach(() => {
    localStorageMock.clear()
    vi.clearAllMocks()
    // Reset document element
    document.documentElement.removeAttribute('data-theme')
  })

  it('initial value reads from localStorage if set', () => {
    localStorageMock.setItem('echo-theme', 'dark')
    
    const { result } = renderHook(() => useTheme())
    
    expect(result.current.theme).toBe('dark')
  })

  it('falls back to system when localStorage is empty', () => {
    const { result } = renderHook(() => useTheme())
    
    expect(result.current.theme).toBe('system')
  })

  it('falls back to system when localStorage has invalid value', () => {
    localStorageMock.setItem('echo-theme', 'invalid')
    
    const { result } = renderHook(() => useTheme())
    
    expect(result.current.theme).toBe('system')
  })

  it('setTheme("dark") applies data-theme="dark" to document.documentElement', () => {
    const { result } = renderHook(() => useTheme())
    
    act(() => {
      result.current.setTheme('dark')
    })
    
    expect(document.documentElement.getAttribute('data-theme')).toBe('dark')
    expect(localStorageMock.setItem).toHaveBeenCalledWith('echo-theme', 'dark')
  })

  it('setTheme("light") removes the attribute', () => {
    const { result } = renderHook(() => useTheme())
    
    // First set to dark to have something to remove
    act(() => {
      result.current.setTheme('dark')
    })
    
    expect(document.documentElement.getAttribute('data-theme')).toBe('dark')
    
    // Then set to light
    act(() => {
      result.current.setTheme('light')
    })
    
    expect(document.documentElement.hasAttribute('data-theme')).toBe(false)
    expect(localStorageMock.setItem).toHaveBeenCalledWith('echo-theme', 'light')
  })

  it('setTheme persists choice to localStorage', () => {
    const { result } = renderHook(() => useTheme())
    
    act(() => {
      result.current.setTheme('dark')
    })
    
    expect(localStorageMock.setItem).toHaveBeenCalledWith('echo-theme', 'dark')
    
    act(() => {
      result.current.setTheme('light')
    })
    
    expect(localStorageMock.setItem).toHaveBeenCalledWith('echo-theme', 'light')
    
    act(() => {
      result.current.setTheme('system')
    })
    
    expect(localStorageMock.setItem).toHaveBeenCalledWith('echo-theme', 'system')
  })

  it('handles localStorage errors gracefully', () => {
    localStorageMock.setItem.mockImplementationOnce(() => {
      throw new Error('Storage error')
    })
    
    const { result } = renderHook(() => useTheme())
    
    expect(() => {
      act(() => {
        result.current.setTheme('dark')
      })
    }).not.toThrow()
  })

  it('applies system theme based on OS preference', () => {
    // Mock OS preference to dark
    window.matchMedia = vi.fn().mockImplementation((query) => ({
      matches: query === '(prefers-color-scheme: dark)',
      media: query,
      onchange: null,
      addListener: vi.fn(),
      removeListener: vi.fn(),
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
      dispatchEvent: vi.fn(),
    }))
    
    const { result } = renderHook(() => useTheme())
    
    act(() => {
      result.current.setTheme('system')
    })
    
    expect(document.documentElement.getAttribute('data-theme')).toBe('dark')
  })

  it('listens to OS preference changes when in system mode', () => {
    const mockAddEventListener = vi.fn()
    const mockRemoveEventListener = vi.fn()
    
    window.matchMedia = vi.fn().mockImplementation((query) => ({
      matches: false,
      media: query,
      onchange: null,
      addListener: vi.fn(),
      removeListener: vi.fn(),
      addEventListener: mockAddEventListener,
      removeEventListener: mockRemoveEventListener,
      dispatchEvent: vi.fn(),
    }))
    
    const { unmount } = renderHook(() => useTheme())
    
    expect(mockAddEventListener).toHaveBeenCalledWith('change', expect.any(Function))
    
    unmount()
    
    expect(mockRemoveEventListener).toHaveBeenCalledWith('change', expect.any(Function))
  })
})
