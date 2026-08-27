import { createClient } from '@supabase/supabase-js'

const rawUrl = import.meta.env.VITE_SUPABASE_URL
const rawKey = import.meta.env.VITE_SUPABASE_ANON_KEY

// Ensure we have a syntactically valid URL to prevent Supabase SDK initialization crash
const isValidUrl = typeof rawUrl === 'string' && (rawUrl.startsWith('http://') || rawUrl.startsWith('https://'))

const supabaseUrl = isValidUrl ? rawUrl : 'https://placeholder-project.supabase.co'
const supabaseAnonKey = typeof rawKey === 'string' && rawKey && rawKey !== 'your-supabase-anon-key-here' ? rawKey : 'placeholder-anon-key'

// Use sessionStorage when the user has explicitly opted out of persistent sessions.
// The preference is stored in localStorage so it survives tab close (but not browser restart).
const rememberMe =
  typeof localStorage !== 'undefined'
    ? localStorage.getItem('echo-remember-me') !== 'false'
    : true

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    storage: rememberMe ? localStorage : sessionStorage,
    // Issue #634: pin PKCE so authorization codes require a stored verifier (CSRF protection)
    flowType: 'pkce',
    detectSessionInUrl: true,
    persistSession: true,
    autoRefreshToken: true,
  },
})
