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

const typeLabels: Record<string, string> = {
  earn: "적립",
  use: "사용",
}

const typeVariants: Record<string, "default" | "destructive"> = {
  earn: "default",
  use: "destructive",
}

export default function PointsPage() {
  const { points, totalPoints, loading, fetchPoints, fetchTotalPoints } = useWelfareStore()
  const { user, isAuthenticated } = useAuthStore()

  useEffect(() => {
    if (isAuthenticated && user) {
      fetchPoints(String(user.id))
      fetchTotalPoints(String(user.id))
    }
  }, [isAuthenticated, user, fetchPoints, fetchTotalPoints])

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
          <CardTitle>보유 포인트</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-3xl font-bold">
            {totalPoints.toLocaleString()} P
          </p>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>포인트 내역</CardTitle>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>구분</TableHead>
                <TableHead>금액</TableHead>
                <TableHead>설명</TableHead>
                <TableHead>일시</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {points.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={4} className="text-center text-muted-foreground">
                    포인트 내역이 없습니다
                  </TableCell>
                </TableRow>
              ) : (
                points.map((point) => (
                  <TableRow key={point.id}>
                    <TableCell>
                      <Badge variant={typeVariants[point.type] || "default"}>
                        {typeLabels[point.type] || point.type}
                      </Badge>
                    </TableCell>
                    <TableCell className={point.type === "use" ? "text-destructive" : ""}>
                      {point.type === "use" ? "-" : "+"}{point.amount.toLocaleString()} P
                    </TableCell>
                    <TableCell>{point.description}</TableCell>
                    <TableCell>
                      {new Date(point.created_at).toLocaleDateString("ko-KR")}
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