import { useEffect } from 'react'

/**
 * A custom hook to attach a global keyboard shortcut.
 * It ensures the shortcut doesn't trigger when the user is typing in an input or textarea.
 *
 * @param key - The key to listen for (e.g., 'k'). Case-insensitive.
 * @param callback - The function to execute when the key is pressed.
 */
export function useGlobalShortcut(key: string, callback: () => void) {
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      const activeElement = document.activeElement as HTMLElement | null
      
      // Do not trigger if the user is typing inside an input, textarea, or contenteditable area
      if (activeElement) {
        const tagName = activeElement.tagName.toLowerCase()
        if (tagName === 'input' || tagName === 'textarea' || activeElement.isContentEditable) {
          return
        }
      }

      // Check if the pressed key matches (case-insensitive)
      if (event.key.toLowerCase() === key.toLowerCase()) {
        event.preventDefault()
        callback()
      }
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [key, callback])
}
