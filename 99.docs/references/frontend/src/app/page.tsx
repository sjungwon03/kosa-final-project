"use client"

import { useEffect, useState } from "react"
import Link from "next/link"
import { useAuthStore } from "@/stores/authStore"
import { useEmployeeStore } from "@/stores/employeeStore"
import { useWelfareStore } from "@/stores/welfareStore"
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Layout } from "@/components/layout"

export default function HomePage() {
  const [mounted, setMounted] = useState(false)
  const { user, isAuthenticated, _hasHydrated } = useAuthStore()
  const { employees, fetchEmployees } = useEmployeeStore()
  const { products, orders, totalPoints, fetchProducts, fetchOrders, fetchTotalPoints } = useWelfareStore()

  useEffect(() => {
    setMounted(true)
  }, [])

  useEffect(() => {
    if (_hasHydrated && isAuthenticated && user) {
      fetchEmployees()
      fetchProducts()
      fetchOrders(user.id)
      fetchTotalPoints(String(user.id))
    }
  }, [_hasHydrated, isAuthenticated, user, fetchEmployees, fetchProducts, fetchOrders, fetchTotalPoints])

  if (!mounted || !_hasHydrated) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <p className="text-muted-foreground">로딩 중...</p>
      </div>
    )
  }

  return (
    <Layout>
      <div className="space-y-6">
        <div className="flex justify-between items-center">
          <h1 className="text-2xl font-bold">대시보드</h1>
          {isAuthenticated && user && (
            <p className="text-muted-foreground">
              {user.name}님, 안녕하세요 ({user.department})
            </p>
          )}
        </div>

        {!isAuthenticated ? (
          <Card>
            <CardContent className="flex flex-col items-center justify-center py-12">
              <p className="text-muted-foreground mb-4">로그인이 필요합니다</p>
              <Link href="/login">
                <Button>로그인</Button>
              </Link>
            </CardContent>
          </Card>
        ) : (
          <>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
              <Card>
                <CardHeader>
                  <CardTitle className="text-sm font-medium text-muted-foreground">
                    전체 사원
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-2xl font-bold">{employees.length}명</p>
                </CardContent>
              </Card>
              <Card>
                <CardHeader>
                  <CardTitle className="text-sm font-medium text-muted-foreground">
                    상품 수
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-2xl font-bold">{products.length}개</p>
                </CardContent>
              </Card>
              <Card>
                <CardHeader>
                  <CardTitle className="text-sm font-medium text-muted-foreground">
                    주문 수
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-2xl font-bold">{orders.length}건</p>
                </CardContent>
              </Card>
              <Card>
                <CardHeader>
                  <CardTitle className="text-sm font-medium text-muted-foreground">
                    보유 포인트
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-2xl font-bold">{totalPoints.toLocaleString()} P</p>
                </CardContent>
              </Card>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <Card>
                <CardHeader className="flex flex-row items-center justify-between">
                  <CardTitle>사원 관리</CardTitle>
                  <Link href="/employees">
                    <Button variant="outline" size="sm">전체 보기</Button>
                  </Link>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    <p className="text-muted-foreground">
                      사원 정보를 등록, 수정, 조회할 수 있습니다
                    </p>
                    <Link href="/employees/new">
                      <Button>사원 등록</Button>
                    </Link>
                  </div>
                </CardContent>
              </Card>

              <Card>
                <CardHeader className="flex flex-row items-center justify-between">
                  <CardTitle>복지 포인트몰</CardTitle>
                  <Link href="/welfare/products">
                    <Button variant="outline" size="sm">전체 보기</Button>
                  </Link>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    <p className="text-muted-foreground">
                      복지 상품을 구매하고 포인트를 관리할 수 있습니다
                    </p>
                    <Link href="/welfare/products">
                      <Button>상품 보기</Button>
                    </Link>
                  </div>
                </CardContent>
              </Card>
            </div>
          </>
        )}
      </div>
    </Layout>
  )
}