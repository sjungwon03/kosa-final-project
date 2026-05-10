"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import { cn } from "@/lib/utils"
import { useAuthStore } from "@/stores/authStore"
import { Button } from "@/components/ui/button"

const navItems = [
  { href: "/", label: "대시보드" },
  { href: "/employees", label: "사원 관리" },
  { href: "/welfare/products", label: "복지 포인트몰" },
  { href: "/welfare/orders", label: "주문 내역" },
  { href: "/welfare/points", label: "포인트 내역" },
]

export function Header() {
  const pathname = usePathname()
  const { user, isAuthenticated, logout, _hasHydrated } = useAuthStore()

  if (!_hasHydrated) {
    return (
      <header className="sticky top-0 z-40 w-full border-b bg-background">
        <div className="container flex h-16 items-center justify-between">
          <Link href="/" className="font-bold text-xl">
            KOSA
          </Link>
          <div className="flex items-center gap-4">
            <Link href="/login">
              <Button size="sm">로그인</Button>
            </Link>
          </div>
        </div>
      </header>
    )
  }

  return (
    <header className="sticky top-0 z-40 w-full border-b bg-background">
      <div className="container flex h-16 items-center justify-between">
        <div className="flex items-center gap-6">
          <Link href="/" className="font-bold text-xl">
            KOSA
          </Link>
          <nav className="hidden md:flex items-center gap-4">
            {navItems.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                className={cn(
                  "text-sm font-medium transition-colors hover:text-primary",
                  pathname === item.href
                    ? "text-primary"
                    : "text-muted-foreground"
                )}
              >
                {item.label}
              </Link>
            ))}
          </nav>
        </div>
        <div className="flex items-center gap-4">
          {isAuthenticated && user ? (
            <>
              <span className="text-sm text-muted-foreground">
                {user.name} ({user.department})
              </span>
              <Button variant="outline" size="sm" onClick={logout}>
                로그아웃
              </Button>
            </>
          ) : (
            <Link href="/login">
              <Button size="sm">로그인</Button>
            </Link>
          )}
        </div>
      </div>
    </header>
  )
}