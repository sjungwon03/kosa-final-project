"use client"

import { useEffect } from "react"
import { useWelfareStore } from "@/stores/welfareStore"
import { useAuthStore } from "@/stores/authStore"
import {
  Card,
  CardHeader,
  CardTitle,
  CardContent,
  CardFooter,
} from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import Link from "next/link"

export default function ProductsPage() {
  const { products, loading, fetchProducts } = useWelfareStore()
  const { isAuthenticated } = useAuthStore()

  useEffect(() => {
    if (isAuthenticated) {
      fetchProducts()
    }
  }, [isAuthenticated, fetchProducts])

  if (!isAuthenticated) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <p className="text-muted-foreground">로그인이 필요합니다</p>
      </div>
    )
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <p className="text-muted-foreground">로딩 중...</p>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold">상품 목록</h1>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {products.length === 0 ? (
          <div className="col-span-full text-center text-muted-foreground">
            등록된 상품이 없습니다
          </div>
        ) : (
          products.map((product) => (
            <Card key={product.id}>
              <CardHeader>
                <img
                  src={product.image_url || "/placeholder.jpg"}
                  alt={product.name}
                  className="w-full h-48 object-cover rounded-t-lg"
                />
              </CardHeader>
              <CardContent>
                <div className="space-y-2">
                  <Badge>{product.category}</Badge>
                  <CardTitle className="text-lg">{product.name}</CardTitle>
                  <p className="text-sm text-muted-foreground line-clamp-2">
                    {product.description}
                  </p>
                  <p className="text-lg font-bold">
                    {product.price.toLocaleString()}원
                  </p>
                  <p className="text-sm text-muted-foreground">
                    재고: {product.stock}개
                  </p>
                </div>
              </CardContent>
              <CardFooter>
                <Link href={`/welfare/products/${product.id}`}>
                  <Button variant="outline" className="w-full">
                    상세 보기
                  </Button>
                </Link>
              </CardFooter>
            </Card>
          ))
        )}
      </div>
    </div>
  )
}