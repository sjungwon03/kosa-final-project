"use client"

import { useEffect } from "react"
import { useWelfareStore } from "@/stores/welfareStore"
import { useAuthStore } from "@/stores/authStore"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card"

const statusLabels: Record<string, string> = {
  pending: "대기",
  processing: "처리중",
  shipped: "배송중",
  delivered: "배송완료",
  cancelled: "취소",
}

const statusVariants: Record<string, "default" | "secondary" | "destructive"> = {
  pending: "secondary",
  processing: "default",
  shipped: "default",
  delivered: "default",
  cancelled: "destructive",
}

export default function OrdersPage() {
  const { orders, loading, fetchOrders } = useWelfareStore()
  const { user, isAuthenticated } = useAuthStore()

  useEffect(() => {
    if (isAuthenticated && user) {
      fetchOrders(user.id)
    }
  }, [isAuthenticated, user, fetchOrders])

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
      <Card>
        <CardHeader>
          <CardTitle>주문 내역</CardTitle>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>주문번호</TableHead>
                <TableHead>상품명</TableHead>
                <TableHead>배송 주소</TableHead>
                <TableHead>연락처</TableHead>
                <TableHead>총 금액</TableHead>
                <TableHead>상태</TableHead>
                <TableHead>주문일</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {orders.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={7} className="text-center text-muted-foreground">
                    주문 내역이 없습니다
                  </TableCell>
                </TableRow>
              ) : (
                orders.map((order) => (
                  <TableRow key={order.id}>
                    <TableCell>{order.order_number}</TableCell>
                    <TableCell>-</TableCell>
                    <TableCell>{order.shipping_address}</TableCell>
                    <TableCell>{order.phone}</TableCell>
                    <TableCell>{order.total_amount.toLocaleString()}원</TableCell>
                    <TableCell>
                      <Badge variant={statusVariants[order.status] || "default"}>
                        {statusLabels[order.status] || order.status}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      {new Date(order.created_at).toLocaleDateString("ko-KR")}
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  )
}