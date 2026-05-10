import { create } from 'zustand'
import type { Product, Order, Point } from '@/types'
import { welfareApi } from '@/lib/api'

interface WelfareState {
  products: Product[]
  currentProduct: Product | null
  orders: Order[]
  points: Point[]
  totalPoints: number
  loading: boolean
  error: string | null
  fetchProducts: (category?: string) => Promise<void>
  fetchProduct: (id: string) => Promise<void>
  createProduct: (data: any) => Promise<void>
  updateProduct: (id: string, data: any) => Promise<void>
  deleteProduct: (id: string) => Promise<void>
  fetchOrders: (employeeId?: number) => Promise<void>
  createOrder: (data: any) => Promise<void>
  fetchPoints: (employeeId: string) => Promise<void>
  fetchTotalPoints: (employeeId: string) => Promise<void>
  earnPoints: (data: any) => Promise<void>
  deductPoints: (data: any) => Promise<void>
}

export const useWelfareStore = create<WelfareState>((set) => ({
  products: [],
  currentProduct: null,
  orders: [],
  points: [],
  totalPoints: 0,
  loading: false,
  error: null,
  
  fetchProducts: async (category?: string) => {
    set({ loading: true, error: null })
    try {
      const response = await welfareApi.getProducts(0, 100, category)
      set({ products: response.data, loading: false })
    } catch (error: any) {
      set({ error: error.message, loading: false })
    }
  },
  
  fetchProduct: async (id: string) => {
    set({ loading: true, error: null })
    try {
      const response = await welfareApi.getProduct(id)
      set({ currentProduct: response.data, loading: false })
    } catch (error: any) {
      set({ error: error.message, loading: false })
    }
  },
  
  createProduct: async (data) => {
    set({ loading: true, error: null })
    try {
      await welfareApi.createProduct(data)
      const response = await welfareApi.getProducts()
      set({ products: response.data, loading: false })
    } catch (error: any) {
      set({ error: error.message, loading: false })
    }
  },
  
  updateProduct: async (id, data) => {
    set({ loading: true, error: null })
    try {
      await welfareApi.updateProduct(id, data)
      const response = await welfareApi.getProducts()
      set({ products: response.data, loading: false })
    } catch (error: any) {
      set({ error: error.message, loading: false })
    }
  },
  
  deleteProduct: async (id) => {
    set({ loading: true, error: null })
    try {
      await welfareApi.deleteProduct(id)
      const response = await welfareApi.getProducts()
      set({ products: response.data, loading: false })
    } catch (error: any) {
      set({ error: error.message, loading: false })
    }
  },
  
  fetchOrders: async (employeeId?: number) => {
    set({ loading: true, error: null })
    try {
      const response = await welfareApi.getOrders(employeeId)
      set({ orders: response.data, loading: false })
    } catch (error: any) {
      set({ error: error.message, loading: false })
    }
  },
  
  createOrder: async (data) => {
    set({ loading: true, error: null })
    try {
      await welfareApi.createOrder(data)
      if (data.employee_id) {
        const response = await welfareApi.getOrders(data.employee_id)
        set({ orders: response.data, loading: false })
      }
    } catch (error: any) {
      set({ error: error.message, loading: false })
    }
  },
  
  fetchPoints: async (employeeId: string) => {
    set({ loading: true, error: null })
    try {
      const response = await welfareApi.getPoints(employeeId)
      set({ points: response.data, loading: false })
    } catch (error: any) {
      set({ error: error.message, loading: false })
    }
  },
  
  fetchTotalPoints: async (employeeId: string) => {
    set({ loading: true, error: null })
    try {
      const response = await welfareApi.getTotalPoints(employeeId)
      set({ totalPoints: response.data.total || 0, loading: false })
    } catch (error: any) {
      set({ error: error.message, loading: false })
    }
  },
  
  earnPoints: async (data) => {
    set({ loading: true, error: null })
    try {
      await welfareApi.earnPoints(data)
      if (data.employee_id) {
        await welfareApi.getPoints(String(data.employee_id))
      }
    } catch (error: any) {
      set({ error: error.message, loading: false })
    }
  },
  
  deductPoints: async (data) => {
    set({ loading: true, error: null })
    try {
      await welfareApi.usePoints(data)
      if (data.employee_id) {
        await welfareApi.getPoints(String(data.employee_id))
      }
    } catch (error: any) {
      set({ error: error.message, loading: false })
    }
  },
}))