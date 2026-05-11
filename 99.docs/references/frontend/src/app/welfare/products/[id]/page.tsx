"use client"

import { useEffect } from "react"
import { useParams, useRouter } from "next/navigation"
import { useWelfareStore } from "@/stores/welfareStore"
import { useAuthStore } from "@/stores/authStore"
import { Card, CardHeader, CardTitle, CardContent, CardFooter } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Label } from "@/components/ui/label"
import { Input } from "@/components/ui/input"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"

const orderSchema = z.object({
  quantity: z.number().min(1, "수량은 1개 이상이어야 합니다"),
  shipping_address: z.string().min(1, "배송 주소를 입력하세요"),
  phone: z.string().min(1, "연락처를 입력하세요"),
})

type OrderFormData = z.infer<typeof orderSchema>

export default function ProductDetailPage() {
  const params = useParams()
  const router = useRouter()
  const { currentProduct, loading, fetchProduct, createOrder } = useWelfareStore()
  const { user, isAuthenticated } = useAuthStore()

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<OrderFormData>({
    resolver: zodResolver(orderSchema),
    defaultValues: {
      quantity: 1,
    },
  })

  useEffect(() => {
    if (isAuthenticated && params.id) {
      fetchProduct(params.id as string)
    }
  }, [isAuthenticated, params.id, fetchProduct])

  const onSubmit = async (data: OrderFormData) => {
    if (!user || !currentProduct) return

    try {
      await createOrder({
        employee_id: user.id,
        items: [{ product_id: currentProduct.id, quantity: data.quantity }],
        shipping_address: data.shipping_address,
        phone: data.phone,
      })
      router.push("/welfare/orders")
    } catch (error) {
      console.error("주문 실패:", error)
    }
  }

  if (!isAuthenticated) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <p className="text-muted-foreground">로그인이 필요합니다</p>
      </div>
    )
  }

  if (loading || !currentProduct) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <p className="text-muted-foreground">로딩 중...</p>
      </div>
    )
  }

  return (
    <div className="max-w-4xl mx-auto">
      <Card>
        <CardHeader>
          <div className="flex gap-6">
            <img
              src={currentProduct.image_url || "/placeholder.jpg"}
              alt={currentProduct.name}
              className="w-1/2 h-64 object-cover rounded-lg"
            />
            <div className="w-1/2 space-y-4">
              <Badge>{currentProduct.category}</Badge>
              <CardTitle className="text-2xl">{currentProduct.name}</CardTitle>
              <p className="text-muted-foreground">{currentProduct.description}</p>
              <p className="text-3xl font-bold">
                {currentProduct.price.toLocaleString()}원
              </p>
              <p className="text-muted-foreground">
                재고: {currentProduct.stock}개
              </p>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="quantity">수량</Label>
              <Input
                id="quantity"
                type="number"
                min={1}
                max={currentProduct.stock}
                {...register("quantity", { valueAsNumber: true })}
              />
              {errors.quantity && (
                <p className="text-sm text-destructive">{errors.quantity.message}</p>
              )}
            </div>
            <div className="space-y-2">
              <Label htmlFor="shipping_address">배송 주소</Label>
              <Input
                id="shipping_address"
                placeholder="서울시 강남구 테헤란로 123"
                {...register("shipping_address")}
              />
              {errors.shipping_address && (
                <p className="text-sm text-destructive">{errors.shipping_address.message}</p>
              )}
            </div>
            <div className="space-y-2">
              <Label htmlFor="phone">연락처</Label>
              <Input
                id="phone"
                placeholder="010-1234-5678"
                {...register("phone")}
              />
              {errors.phone && (
                <p className="text-sm text-destructive">{errors.phone.message}</p>
              )}
            </div>
          </form>
        </CardContent>
        <CardFooter className="flex justify-between">
          <Button variant="outline" onClick={() => router.back()}>
            목록
          </Button>
          <Button onClick={handleSubmit(onSubmit)} disabled={loading || currentProduct.stock === 0}>
            {currentProduct.stock === 0 ? "재고 없음" : "주문하기"}
          </Button>
        </CardFooter>
      </Card>
    </div>
  )
}