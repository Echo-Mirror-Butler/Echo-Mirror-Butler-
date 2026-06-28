import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error(
    'Missing Supabase environment variables. Please set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY in your .env.local file.'
  )
}

// Use sessionStorage when the user has explicitly opted out of persistent sessions.
// The preference is stored in localStorage so it survives tab close (but not browser restart).
const rememberMe =
  typeof localStorage !== 'undefined'
    ? localStorage.getItem('echo-remember-me') !== 'false'
    : true

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    storage: rememberMe ? localStorage : sessionStorage,
  },
})
