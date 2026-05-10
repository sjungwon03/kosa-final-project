"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { employeeApi } from "@/lib/api"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select } from "@/components/ui/select"
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
  CardFooter,
} from "@/components/ui/card"
import Link from "next/link"

const signupSchema = z.object({
  employee_id: z.string().min(1, "사번을 입력하세요"),
  name: z.string().min(1, "이름을 입력하세요"),
  email: z.string().email("올바른 이메일 형식을 입력하세요"),
  department: z.string().min(1, "부서를 선택하세요"),
  position: z.string().min(1, "직급을 입력하세요"),
  phone: z.string().min(1, "연락처를 입력하세요"),
  hire_date: z.string().min(1, "입사일을 입력하세요"),
  password: z.string().min(6, "비밀번호는 최소 6자 이상이어야 합니다"),
})

type SignupFormData = z.infer<typeof signupSchema>

const departments = [
  "개발팀",
  "기술팀",
  "영업팀",
  "마케팅팀",
  "인사팀",
  "재무팀",
]

export default function SignupPage() {
  const router = useRouter()
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<SignupFormData>({
    resolver: zodResolver(signupSchema),
    defaultValues: {
      employee_id: `EMP${Date.now().toString().slice(-4)}`,
      hire_date: new Date().toISOString().split("T")[0],
    },
  })

  const onSubmit = async (data: SignupFormData) => {
    setLoading(true)
    setError(null)
    try {
      const response = await employeeApi.create({
        employee_id: data.employee_id,
        name: data.name,
        email: data.email,
        department: data.department,
        position: data.position,
        phone: data.phone,
        hire_date: `${data.hire_date}T00:00:00`,
        password: data.password,
      })
      console.log('Signup successful:', response.data)
      router.push("/login")
    } catch (err: any) {
      console.error('Signup error:', err.response?.data)
      const detail = err.response?.data?.detail
      if (Array.isArray(detail)) {
        setError(detail.map((d: any) => d.msg).join(', '))
      } else {
        setError(detail || "회원가입에 실패했습니다")
      }
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-background">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle>회원가입</CardTitle>
          <CardDescription>
            KOSA 사원 관리 시스템에 가입하세요
          </CardDescription>
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
                placeholder="사원"
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
            {error && (
              <p className="text-sm text-destructive">{error}</p>
            )}
            <Button type="submit" className="w-full" disabled={loading}>
              {loading ? "가입 중..." : "회원가입"}
            </Button>
          </form>
        </CardContent>
        <CardFooter className="flex justify-center">
          <p className="text-sm text-muted-foreground">
            이미 계정이 있으신가요?{" "}
            <Link href="/login" className="text-primary hover:underline">
              로그인
            </Link>
          </p>
        </CardFooter>
      </Card>
    </div>
  )
}