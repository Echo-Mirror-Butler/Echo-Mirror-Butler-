import { createClient } from '@supabase/supabase-js'

const rawUrl = import.meta.env.VITE_SUPABASE_URL
const rawKey = import.meta.env.VITE_SUPABASE_ANON_KEY

// Ensure we have a syntactically valid URL to prevent Supabase SDK initialization crash
const isValidUrl = typeof rawUrl === 'string' && (rawUrl.startsWith('http://') || rawUrl.startsWith('https://'))

const supabaseUrl = isValidUrl ? rawUrl : 'https://placeholder-project.supabase.co'
const supabaseAnonKey = typeof rawKey === 'string' && rawKey && rawKey !== 'your-supabase-anon-key-here' ? rawKey : 'placeholder-anon-key'

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
