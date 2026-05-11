import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'
import type { Employee } from '@/types'

interface AuthState {
  token: string | null
  user: Employee | null
  isAuthenticated: boolean
  _hasHydrated: boolean
  login: (token: string, user: Employee) => void
  logout: () => void
  setUser: (user: Employee) => void
  setHasHydrated: (state: boolean) => void
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      token: null,
      user: null,
      isAuthenticated: false,
      _hasHydrated: false,
      login: (token, user) => set({ token, user, isAuthenticated: true }),
      logout: () => set({ token: null, user: null, isAuthenticated: false }),
      setUser: (user) => set({ user }),
      setHasHydrated: (state) => set({ _hasHydrated: state }),
    }),
    {
      name: 'auth-storage',
      storage: createJSONStorage(() => localStorage),
      onRehydrateStorage: () => (state) => {
        state?.setHasHydrated(true)
      },
    }
  )
)