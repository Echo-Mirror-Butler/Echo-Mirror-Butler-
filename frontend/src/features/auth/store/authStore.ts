import { create } from 'zustand'
import { supabase } from '@/lib/supabase'
import type { User, AuthState } from '@/types/auth'

interface AuthStore extends AuthState {
  setUser: (user: User | null) => void
  setLoading: (loading: boolean) => void
  signOut: () => Promise<void>
  initialize: () => void
}

export const useAuthStore = create<AuthStore>((set) => ({
  user: null,
  isLoading: true,

  setUser: (user) => set({ user }),
  setLoading: (isLoading) => set({ isLoading }),

  signOut: async () => {
    await supabase.auth.signOut()
    set({ user: null })
  },

  initialize: () => {
    // Check initial session
    supabase.auth.getSession().then(({ data: { session } }) => {
      const user = session?.user
        ? { id: session.user.id, email: session.user.email || '' }
        : null
      set({ user, isLoading: false })
    })

    // Listen for auth changes
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      const user = session?.user
        ? { id: session.user.id, email: session.user.email || '' }
        : null
      set({ user, isLoading: false })
    })

    return () => subscription.unsubscribe()
  },
}))
