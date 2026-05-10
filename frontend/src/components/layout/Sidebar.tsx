"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import { cn } from "@/lib/utils"

const menuItems = [
  {
    title: "사원 관리",
    items: [
      { href: "/employees", label: "사원 목록" },
      { href: "/employees/new", label: "사원 등록" },
    ],
  },
  {
    title: "복지 포인트몰",
    items: [
      { href: "/welfare/products", label: "상품 목록" },
      { href: "/welfare/orders", label: "주문 내역" },
      { href: "/welfare/points", label: "포인트 내역" },
    ],
  },
]

export function Sidebar() {
  const pathname = usePathname()

  return (
    <aside className="hidden md:flex w-64 flex-col border-r bg-background">
      <div className="flex-1 space-y-4 p-4">
        {menuItems.map((group) => (
          <div key={group.title} className="space-y-2">
            <h3 className="font-semibold text-sm text-muted-foreground">
              {group.title}
            </h3>
            <nav className="space-y-1">
              {group.items.map((item) => (
                <Link
                  key={item.href}
                  href={item.href}
                  className={cn(
                    "flex items-center rounded-md px-3 py-2 text-sm font-medium transition-colors",
                    pathname === item.href
                      ? "bg-primary text-primary-foreground"
                      : "hover:bg-accent hover:text-accent-foreground"
                  )}
                >
                  {item.label}
                </Link>
              ))}
            </nav>
          </div>
        ))}
      </div>
    </aside>
  )
}