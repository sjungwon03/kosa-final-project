"use client"

import { useEffect } from "react"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { useParams, useRouter } from "next/navigation"
import { useEmployeeStore } from "@/stores/employeeStore"
import { useAuthStore } from "@/stores/authStore"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select } from "@/components/ui/select"
import { Card, CardHeader, CardTitle, CardContent, CardFooter } from "@/components/ui/card"

const updateSchema = z.object({
  name: z.string().min(1, "이름을 입력하세요").optional(),
  email: z.string().email("올바른 이메일 형식을 입력하세요").optional(),
  department: z.string().optional(),
  position: z.string().optional(),
  phone: z.string().optional(),
  status: z.string().optional(),
})

type UpdateFormData = z.infer<typeof updateSchema>

const departments = [
  "개발팀",
  "기술팀",
  "영업팀",
  "마케팅팀",
  "인사팀",
  "재무팀",
]

const statuses = [
  { value: "active", label: "활성" },
  { value: "inactive", label: "비활성" },
]

export default function EditEmployeePage() {
  const params = useParams()
  const router = useRouter()
  const { currentEmployee, loading, fetchEmployee, updateEmployee } = useEmployeeStore()
  const { isAuthenticated } = useAuthStore()

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors },
  } = useForm<UpdateFormData>({
    resolver: zodResolver(updateSchema),
  })

  useEffect(() => {
    if (isAuthenticated && params.id) {
      fetchEmployee(params.id as string)
    }
  }, [isAuthenticated, params.id, fetchEmployee])

  useEffect(() => {
    if (currentEmployee) {
      reset({
        name: currentEmployee.name,
        email: currentEmployee.email,
        department: currentEmployee.department,
        position: currentEmployee.position,
        phone: currentEmployee.phone,
        status: currentEmployee.status,
      })
    }
  }, [currentEmployee, reset])

  const onSubmit = async (data: UpdateFormData) => {
    try {
      await updateEmployee(params.id as string, data)
      router.push("/employees")
    } catch (error) {
      console.error("사원 수정 실패:", error)
    }
  }

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
    <div className="max-w-2xl mx-auto">
      <Card>
        <CardHeader>
          <CardTitle>사원 정보 수정 - {currentEmployee.employee_id}</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="name">이름</Label>
              <Input
                id="name"
                {...register("name")}
              />
              {errors.name && (
                <p className="text-sm text-destructive">{errors.name.message}</p>
              )}
            </div>
            <div className="space-y-2">
              <Label htmlFor="email">이메일</Label>
              <Input
                id="email"
                type="email"
                {...register("email")}
              />
              {errors.email && (
                <p className="text-sm text-destructive">{errors.email.message}</p>
              )}
            </div>
            <div className="space-y-2">
              <Label htmlFor="department">부서</Label>
              <Select {...register("department")}>
                {departments.map((dept) => (
                  <option key={dept} value={dept}>{dept}</option>
                ))}
              </Select>
            </div>
            <div className="space-y-2">
              <Label htmlFor="position">직급</Label>
              <Input
                id="position"
                {...register("position")}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="phone">연락처</Label>
              <Input
                id="phone"
                {...register("phone")}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="status">상태</Label>
              <Select {...register("status")}>
                {statuses.map((status) => (
                  <option key={status.value} value={status.value}>{status.label}</option>
                ))}
              </Select>
            </div>
          </form>
        </CardContent>
        <CardFooter className="flex justify-between">
          <Button variant="outline" onClick={() => router.back()}>
            취소
          </Button>
          <Button onClick={handleSubmit(onSubmit)} disabled={loading}>
            {loading ? "수정 중..." : "수정"}
          </Button>
        </CardFooter>
      </Card>
    </div>
  )
}