"use client"

import { useEffect } from "react"
import { useParams, useRouter } from "next/navigation"
import { useEmployeeStore } from "@/stores/employeeStore"
import { useAuthStore } from "@/stores/authStore"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card"
import Link from "next/link"

export default function EmployeeDetailPage() {
  const params = useParams()
  const router = useRouter()
  const { currentEmployee, loading, fetchEmployee } = useEmployeeStore()
  const { isAuthenticated } = useAuthStore()

  useEffect(() => {
    if (isAuthenticated && params.id) {
      fetchEmployee(params.id as string)
    }
  }, [isAuthenticated, params.id, fetchEmployee])

  if (!isAuthenticated) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <p className="text-muted-foreground">로그인이 필요합니다</p>
      </div>
    )
  }

  if (loading || !currentEmployee) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <p className="text-muted-foreground">로딩 중...</p>
      </div>
    )
  }

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle>사원 상세 정보</CardTitle>
          <div className="flex gap-2">
            <Link href={`/employees/${currentEmployee.employee_id}/edit`}>
              <Button variant="outline">수정</Button>
            </Link>
            <Button variant="outline" onClick={() => router.back()}>
              목록
            </Button>
          </div>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <p className="text-sm text-muted-foreground">사번</p>
              <p className="font-medium">{currentEmployee.employee_id}</p>
            </div>
            <div>
              <p className="text-sm text-muted-foreground">이름</p>
              <p className="font-medium">{currentEmployee.name}</p>
            </div>
            <div>
              <p className="text-sm text-muted-foreground">이메일</p>
              <p className="font-medium">{currentEmployee.email}</p>
            </div>
            <div>
              <p className="text-sm text-muted-foreground">부서</p>
              <p className="font-medium">{currentEmployee.department}</p>
            </div>
            <div>
              <p className="text-sm text-muted-foreground">직급</p>
              <p className="font-medium">{currentEmployee.position}</p>
            </div>
            <div>
              <p className="text-sm text-muted-foreground">연락처</p>
              <p className="font-medium">{currentEmployee.phone}</p>
            </div>
            <div>
              <p className="text-sm text-muted-foreground">입사일</p>
              <p className="font-medium">
                {new Date(currentEmployee.hire_date).toLocaleDateString("ko-KR")}
              </p>
            </div>
            <div>
              <p className="text-sm text-muted-foreground">상태</p>
              <Badge variant={currentEmployee.status === "active" ? "default" : "secondary"}>
                {currentEmployee.status === "active" ? "활성" : "비활성"}
              </Badge>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}