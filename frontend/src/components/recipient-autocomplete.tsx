import { useState, useEffect, useRef } from 'react'
import { supabase } from '../lib/supabase'
import { useAuth } from '../lib/auth-context'

type UserSuggestion = {
  id: string
  email: string
  display_name?: string
}

type RecipientAutocompleteProps = {
  value: string
  onChange: (value: string) => void
  onSelect: (userId: string) => void
  placeholder?: string
}

export function RecipientAutocomplete({ 
  value, 
  onChange, 
  onSelect, 
  placeholder = "UUID or email" 
}: RecipientAutocompleteProps) {
  const { user } = useAuth()
  const [suggestions, setSuggestions] = useState<UserSuggestion[]>([])
  const [isOpen, setIsOpen] = useState(false)
  const [selectedIndex, setSelectedIndex] = useState(-1)
  const [isLoading, setIsLoading] = useState(false)
  const inputRef = useRef<HTMLInputElement>(null)
  const debounceRef = useRef<ReturnType<typeof setTimeout>>(undefined)

  // Reset suggestions when input changes
  useEffect(() => {
    setSelectedIndex(-1)
  }, [suggestions])

  // Fetch suggestions when input meets criteria
  useEffect(() => {
    if (debounceRef.current) {
      clearTimeout(debounceRef.current)
    }

    const shouldSearch = value.length >= 3 && value.includes('@')

    if (!shouldSearch) {
      setSuggestions([])
      setIsOpen(false)
      return
    }

    debounceRef.current = setTimeout(() => {
      fetchSuggestions(value)
    }, 300)

    return () => {
      if (debounceRef.current) {
        clearTimeout(debounceRef.current)
      }
    }
  }, [value, user?.id])

  async function fetchSuggestions(query: string) {
    if (!user?.id) return

    setIsLoading(true)
    try {
      // Try profiles table first, then user_profiles
      const profileTables = ['profiles', 'user_profiles']
      let results: UserSuggestion[] = []

      for (const table of profileTables) {
        try {
          const { data, error } = await supabase
            .from(table)
            .select('id, email, display_name')
            .ilike('email', `%${query}%`)
            .neq('id', user.id)
            .limit(5)

          if (!error && data) {
            results = data as UserSuggestion[]
            break
          }
        } catch {
          // Continue to next table if this one fails
          continue
        }
      }

      setSuggestions(results)
      setIsOpen(results.length > 0)
    } catch (error) {
      console.error('Error fetching suggestions:', error)
      setSuggestions([])
      setIsOpen(false)
    } finally {
      setIsLoading(false)
    }
  }

  function handleKeyDown(event: React.KeyboardEvent) {
    if (!isOpen) return

    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault()
        setSelectedIndex((prev) => 
          prev < suggestions.length - 1 ? prev + 1 : prev
        )
        break
      case 'ArrowUp':
        event.preventDefault()
        setSelectedIndex((prev) => (prev > 0 ? prev - 1 : -1))
        break
      case 'Enter':
        event.preventDefault()
        if (selectedIndex >= 0 && selectedIndex < suggestions.length) {
          handleSelect(suggestions[selectedIndex])
        }
        break
      case 'Escape':
        setIsOpen(false)
        setSelectedIndex(-1)
        inputRef.current?.focus()
        break
    }
  }

  function handleSelect(suggestion: UserSuggestion) {
    onSelect(suggestion.id)
    onChange(suggestion.id) // Fill input with user ID
    setIsOpen(false)
    setSelectedIndex(-1)
  }

  function handleClickOutside(event: MouseEvent) {
    if (inputRef.current && !inputRef.current.contains(event.target as Node)) {
      setIsOpen(false)
    }
  }

  useEffect(() => {
    document.addEventListener('mousedown', handleClickOutside)
    return () => {
      document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [])

  return (
    <div className="recipient-autocomplete">
      <input
        ref={inputRef}
        type="text"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onKeyDown={handleKeyDown}
        placeholder={placeholder}
        className={isLoading ? 'loading' : ''}
      />
      
      {isOpen && (
        <ul className="suggestions-list">
          {suggestions.map((suggestion, index) => (
            <li
              key={suggestion.id}
              className={index === selectedIndex ? 'selected' : ''}
              onClick={() => handleSelect(suggestion)}
            >
              <div className="suggestion-email">{suggestion.email}</div>
              {suggestion.display_name && (
                <div className="suggestion-name">{suggestion.display_name}</div>
              )}
            </li>
          ))}
        </ul>
      )}
      
      <style>{`
        .recipient-autocomplete {
          position: relative;
        }

        .suggestions-list {
          position: absolute;
          top: 100%;
          left: 0;
          right: 0;
          background: white;
          border: 1px solid #e5e7eb;
          border-radius: 0.375rem;
          box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
          max-height: 200px;
          overflow-y: auto;
          z-index: 50;
          margin: 0;
          padding: 0;
          list-style: none;
        }

        .suggestions-list li {
          padding: 0.5rem 0.75rem;
          cursor: pointer;
          border-bottom: 1px solid #f3f4f6;
        }

        .suggestions-list li:last-child {
          border-bottom: none;
        }

        .suggestions-list li:hover,
        .suggestions-list li.selected {
          background-color: #f3f4f6;
        }

        .suggestion-email {
          font-size: 0.875rem;
          color: #374151;
        }

        .suggestion-name {
          font-size: 0.75rem;
          color: #6b7280;
          margin-top: 0.125rem;
        }

        input.loading {
          background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='%239ca3af' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M21 12a9 9 0 1 1-6.219-8.56'/%3E%3C/svg%3E");
          background-repeat: no-repeat;
          background-position: right 0.5rem center;
          background-size: 1rem;
          padding-right: 2rem;
        }
      `}</style>
    </div>
  )
}
