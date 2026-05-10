export interface Employee {
  id: number
  employee_id: string
  name: string
  email: string
  department: string
  position: string
  phone: string
  hire_date: string
  status: string
  created_at: string
  updated_at: string
}

export interface EmployeeCreate {
  employee_id: string
  name: string
  email: string
  department: string
  position: string
  phone: string
  hire_date: string
  password: string
}

export interface EmployeeUpdate {
  name?: string
  email?: string
  department?: string
  position?: string
  phone?: string
  status?: string
}

export interface LoginRequest {
  email: string
  password: string
}

export interface TokenResponse {
  access_token: string
  token_type: string
}

export interface Product {
  id: number
  name: string
  description: string
  price: number
  stock: number
  category: string
  image_url: string
  created_at: string
  updated_at: string
}

export interface ProductCreate {
  name: string
  description: string
  price: number
  stock: number
  category: string
  image_url: string
}

export interface ProductUpdate {
  name?: string
  description?: string
  price?: number
  stock?: number
  category?: string
  image_url?: string
}

export interface OrderItem {
  product_id: number
  quantity: number
}

export interface OrderCreate {
  employee_id: number
  items: OrderItem[]
  shipping_address: string
  phone: string
}

export interface Order {
  id: number
  employee_id: number
  order_number: string
  total_amount: number
  status: string
  shipping_address: string
  phone: string
  created_at: string
  updated_at: string
}

export interface PointCreate {
  employee_id: number
  amount: number
  type: string
  description: string
}

export interface Point {
  id: number
  employee_id: number
  amount: number
  type: string
  description: string
  created_at: string
}