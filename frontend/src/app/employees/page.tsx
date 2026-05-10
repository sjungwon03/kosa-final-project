"use client"

import { useEffect, useState } from "react"
import { useEmployeeStore } from "@/stores/employeeStore"
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
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select } from "@/components/ui/select"
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from "@/components/ui/dialog"
import Link from "next/link"

export default function EmployeesPage() {
  const { employees, loading, fetchEmployees, deleteEmployee } = useEmployeeStore()
  const { earnPoints, deductPoints, fetchTotalPoints, totalPoints } = useWelfareStore()
  const { isAuthenticated } = useAuthStore()
  const [pointDialog, setPointDialog] = useState<{
    open: boolean
    employeeId: number | null
    employeeName: string
    action: "earn" | "use"
  }>({
    open: false,
    employeeId: null,
    employeeName: "",
    action: "earn",
  })
  const [pointAmount, setPointAmount] = useState("")
  const [pointDescription, setPointDescription] = useState("")

  useEffect(() => {
    if (isAuthenticated) {
      fetchEmployees()
    }
  }, [isAuthenticated, fetchEmployees])

  const handlePointAction = async () => {
    if (!pointDialog.employeeId || !pointAmount || !pointDescription) return
    
    const amount = parseFloat(pointAmount)
    if (isNaN(amount) || amount <= 0) return
    
    try {
      if (pointDialog.action === "earn") {
        await earnPoints({
          employee_id: pointDialog.employeeId,
          amount: amount,
          type: "earn",
          description: pointDescription,
        })
      } else {
        await deductPoints({
          employee_id: pointDialog.employeeId,
          amount: amount,
          type: "use",
          description: pointDescription,
        })
      }
      setPointDialog({ open: false, employeeId: null, employeeName: "", action: "earn" })
      setPointAmount("")
      setPointDescription("")
    } catch (error) {
      console.error("포인트 처리 실패:", error)
    }
  }

  const openPointDialog = (employee: any, action: "earn" | "use") => {
    setPointDialog({
      open: true,
      employeeId: employee.id,
      employeeName: employee.name,
      action,
    })
    if (action === "earn") {
      setPointDescription("관리자 적립")
    } else {
      setPointDescription("관리자 차감")
    }
    fetchTotalPoints(String(employee.id))
  }

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
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle>사원 목록</CardTitle>
          <Link href="/employees/new">
            <Button>사원 등록</Button>
          </Link>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>사번</TableHead>
                <TableHead>이름</TableHead>
                <TableHead>이메일</TableHead>
                <TableHead>부서</TableHead>
                <TableHead>직급</TableHead>
                <TableHead>연락처</TableHead>
                <TableHead>상태</TableHead>
                <TableHead>포인트</TableHead>
                <TableHead>작업</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {employees.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={9} className="text-center text-muted-foreground">
                    등록된 사원이 없습니다
                  </TableCell>
                </TableRow>
              ) : (
                employees.map((employee) => (
                  <TableRow key={employee.id}>
                    <TableCell>{employee.employee_id}</TableCell>
                    <TableCell>{employee.name}</TableCell>
                    <TableCell>{employee.email}</TableCell>
                    <TableCell>{employee.department}</TableCell>
                    <TableCell>{employee.position}</TableCell>
                    <TableCell>{employee.phone}</TableCell>
                    <TableCell>
                      <Badge variant={employee.status === "active" ? "default" : "secondary"}>
                        {employee.status === "active" ? "활성" : "비활성"}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      <div className="flex gap-1">
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => openPointDialog(employee, "earn")}
                        >
                          적립
                        </Button>
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => openPointDialog(employee, "use")}
                        >
                          사용
                        </Button>
                      </div>
                    </TableCell>
                    <TableCell>
                      <div className="flex gap-2">
                        <Link href={`/employees/${employee.employee_id}`}>
                          <Button variant="outline" size="sm">상세</Button>
                        </Link>
                        <Link href={`/employees/${employee.employee_id}/edit`}>
                          <Button variant="outline" size="sm">수정</Button>
                        </Link>
                        <Button
                          variant="destructive"
                          size="sm"
                          onClick={() => deleteEmployee(employee.employee_id)}
                        >
                          삭제
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      <Dialog open={pointDialog.open} onOpenChange={(open) => setPointDialog({ ...pointDialog, open })}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {pointDialog.action === "earn" ? "포인트 적립" : "포인트 사용"}
            </DialogTitle>
            <DialogDescription>
              {pointDialog.employeeName} 사원의 포인트를 {pointDialog.action === "earn" ? "적립" : "사용"}합니다
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="amount">포인트 금액</Label>
              <Input
                id="amount"
                type="number"
                placeholder="0"
                value={pointAmount}
                onChange={(e) => setPointAmount(e.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="description">설명</Label>
              <Input
                id="description"
                placeholder={pointDialog.action === "earn" ? "적립 사유" : "사용 사유"}
                value={pointDescription}
                onChange={(e) => setPointDescription(e.target.value)}
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setPointDialog({ ...pointDialog, open: false })}>
              취소
            </Button>
            <Button onClick={handlePointAction}>
              {pointDialog.action === "earn" ? "적립" : "사용"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}