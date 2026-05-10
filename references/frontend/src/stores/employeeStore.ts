import { create } from 'zustand'
import type { Employee } from '@/types'
import { employeeApi } from '@/lib/api'

interface EmployeeState {
  employees: Employee[]
  currentEmployee: Employee | null
  loading: boolean
  error: string | null
  fetchEmployees: () => Promise<void>
  fetchEmployee: (id: string) => Promise<void>
  createEmployee: (data: any) => Promise<void>
  updateEmployee: (id: string, data: any) => Promise<void>
  deleteEmployee: (id: string) => Promise<void>
  setCurrentEmployee: (employee: Employee | null) => void
}

export const useEmployeeStore = create<EmployeeState>((set) => ({
  employees: [],
  currentEmployee: null,
  loading: false,
  error: null,
  
  fetchEmployees: async () => {
    set({ loading: true, error: null })
    try {
      const response = await employeeApi.getAll()
      set({ employees: response.data, loading: false })
    } catch (error: any) {
      set({ error: error.message, loading: false })
    }
  },
  
  fetchEmployee: async (id: string) => {
    set({ loading: true, error: null })
    try {
      const response = await employeeApi.get(id)
      set({ currentEmployee: response.data, loading: false })
    } catch (error: any) {
      set({ error: error.message, loading: false })
    }
  },
  
  createEmployee: async (data) => {
    set({ loading: true, error: null })
    try {
      await employeeApi.create(data)
      const response = await employeeApi.getAll()
      set({ employees: response.data, loading: false })
    } catch (error: any) {
      set({ error: error.message, loading: false })
    }
  },
  
  updateEmployee: async (id, data) => {
    set({ loading: true, error: null })
    try {
      await employeeApi.update(id, data)
      const response = await employeeApi.getAll()
      set({ employees: response.data, loading: false })
    } catch (error: any) {
      set({ error: error.message, loading: false })
    }
  },
  
  deleteEmployee: async (id) => {
    set({ loading: true, error: null })
    try {
      await employeeApi.delete(id)
      const response = await employeeApi.getAll()
      set({ employees: response.data, loading: false })
    } catch (error: any) {
      set({ error: error.message, loading: false })
    }
  },
  
  setCurrentEmployee: (employee) => set({ currentEmployee: employee }),
}))