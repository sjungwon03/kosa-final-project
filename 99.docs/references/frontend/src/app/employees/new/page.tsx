"use client"

import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { useRouter } from "next/navigation"
import { useEmployeeStore } from "@/stores/employeeStore"
import { useAuthStore } from "@/stores/authStore"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select } from "@/components/ui/select"
import { Card, CardHeader, CardTitle, CardContent, CardFooter } from "@/components/ui/card"

const employeeSchema = z.object({
  employee_id: z.string().min(1, "사번을 입력하세요"),
  name: z.string().min(1, "이름을 입력하세요"),
  email: z.string().email("올바른 이메일 형식을 입력하세요"),
  department: z.string().min(1, "부서를 선택하세요"),
  position: z.string().min(1, "직급을 입력하세요"),
  phone: z.string().min(1, "연락처를 입력하세요"),
  hire_date: z.string().min(1, "입사일을 입력하세요"),
  password: z.string().min(6, "비밀번호는 최소 6자 이상이어야 합니다"),
})

type EmployeeFormData = z.infer<typeof employeeSchema>

const departments = [
  "개발팀",
  "기술팀",
  "영업팀",
  "마케팅팀",
  "인사팀",
  "재무팀",
]

export default function NewEmployeePage() {
  const router = useRouter()
  const { createEmployee, loading } = useEmployeeStore()
  const { isAuthenticated } = useAuthStore()

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<EmployeeFormData>({
    resolver: zodResolver(employeeSchema),
  })

  const onSubmit = async (data: EmployeeFormData) => {
    try {
      await createEmployee({
        ...data,
        hire_date: new Date(data.hire_date).toISOString(),
      })
      router.push("/employees")
    } catch (error) {
      console.error("사원 등록 실패:", error)
    }
  }

  if (!isAuthenticated) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <p className="text-muted-foreground">로그인이 필요합니다</p>
      </div>
    )
  }

  return (
    <div className="max-w-2xl mx-auto">
      <Card>
        <CardHeader>
          <CardTitle>사원 등록</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="employee_id">사번</Label>
              <Input
                id="employee_id"
                placeholder="EMP001"
                {...register("employee_id")}
              />
              {errors.employee_id && (
                <p className="text-sm text-destructive">{errors.employee_id.message}</p>
              )}
            </div>
            <div className="space-y-2">
              <Label htmlFor="name">이름</Label>
              <Input
                id="name"
                placeholder="홍길동"
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
                placeholder="user@example.com"
                {...register("email")}
              />
              {errors.email && (
                <p className="text-sm text-destructive">{errors.email.message}</p>
              )}
            </div>
            <div className="space-y-2">
              <Label htmlFor="department">부서</Label>
              <Select {...register("department")}>
                <option value="">부서 선택</option>
                {departments.map((dept) => (
                  <option key={dept} value={dept}>{dept}</option>
                ))}
              </Select>
              {errors.department && (
                <p className="text-sm text-destructive">{errors.department.message}</p>
              )}
            </div>
            <div className="space-y-2">
              <Label htmlFor="position">직급</Label>
              <Input
                id="position"
                placeholder="시니어 개발자"
                {...register("position")}
              />
              {errors.position && (
                <p className="text-sm text-destructive">{errors.position.message}</p>
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
            <div className="space-y-2">
              <Label htmlFor="hire_date">입사일</Label>
              <Input
                id="hire_date"
                type="date"
                {...register("hire_date")}
              />
              {errors.hire_date && (
                <p className="text-sm text-destructive">{errors.hire_date.message}</p>
              )}
            </div>
            <div className="space-y-2">
              <Label htmlFor="password">비밀번호</Label>
              <Input
                id="password"
                type="password"
                placeholder="비밀번호를 입력하세요"
                {...register("password")}
              />
              {errors.password && (
                <p className="text-sm text-destructive">{errors.password.message}</p>
              )}
            </div>
          </form>
        </CardContent>
        <CardFooter className="flex justify-between">
          <Button variant="outline" onClick={() => router.back()}>
            취소
          </Button>
          <Button onClick={handleSubmit(onSubmit)} disabled={loading}>
            {loading ? "등록 중..." : "등록"}
          </Button>
        </CardFooter>
      </Card>
    </div>
  )
}