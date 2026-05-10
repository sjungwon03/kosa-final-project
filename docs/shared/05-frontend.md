# Frontend (React + Next.js)

## 1. 개요

React 18과 Next.js 14를 사용한 프론트엔드 애플리케이션입니다. shadcn/ui 컴포넌트와 Tailwind CSS를 사용하여 디자인 시스템을 구축했습니다.

## 2. 기술 스택

- **React**: 18.3.1
- **Next.js**: 14.2.0
- **UI**: shadcn/ui (Radix UI + Tailwind)
- **State**: Zustand
- **Form**: React Hook Form + Zod
- **HTTP**: Axios
- **Style**: Tailwind CSS

## 3. 디자인 시스템

### 3.1 shadcn/ui 컴포넌트
- Button, Input, Select, Dialog
- Table, Card, Badge
- Toast, Alert

### 3.2 색상 시스템
```css
--background: 0 0% 100%
--foreground: 222.2 84% 4.9%
--primary: 221.2 83.2% 53.3%  /* Blue */
--secondary: 210 40% 96.1%
--destructive: 0 84.2% 60.2%  /* Red */
```

### 3.3 Typography
- Font: Inter
- Sizes: xs, sm, base, lg, xl, 2xl

## 4. 프로젝트 구조

```
frontend/
├── src/
│   ├── app/
│   │   ├── layout.tsx        # Root Layout
│   │   ├── page.tsx          # Home Page
│   │   ├── globals.css       # Global Styles
│   │   └── employees/        # 사원 관리 페이지
│   │   └── welfare/          # 복지 포인트몰 페이지
│   ├── components/
│   │   ├── ui/               # shadcn 컴포넌트
│   │   ├── layout/           # Layout 컴포넌트
│   │   └── features/         # Feature 컴포넌트
│   ├── lib/
│   │   ├── api.ts            # API 호출
│   │   ├── utils.ts          # 유틸리티
│   │   └── auth.ts           # 인증 관련
│   └── stores/
│   │   ├── authStore.ts      # Auth Store
│   │   └── employeeStore.ts  # Employee Store
├── public/
├── package.json
├── tailwind.config.ts
└── tsconfig.json
```

## 5. 페이지 구성

### 5.1 Home Page (/)
- 대시보드
- 로그인 버튼

### 5.2 Employee Pages
- `/employees`: 사원 목록
- `/employees/new`: 사원 등록
- `/employees/{id}`: 사원 상세
- `/employees/{id}/edit`: 사원 수정

### 5.3 Welfare Pages
- `/welfare/products`: 상품 목록
- `/welfare/products/{id}`: 상품 상세
- `/welfare/orders`: 주문 내역
- `/welfare/points`: 포인트 내역

## 6. 상태 관리

### 6.1 Zustand Store

```typescript
// authStore.ts
import { create } from 'zustand'

interface AuthState {
  token: string | null
  user: User | null
  login: (token: string) => void
  logout: () => void
}

export const useAuthStore = create<AuthState>((set) => ({
  token: null,
  user: null,
  login: (token) => set({ token }),
  logout: () => set({ token: null, user: null }),
}))
```

## 7. API 연동

### 7.1 Axios 설정

```typescript
// lib/api.ts
import axios from 'axios'

const api = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000',
  headers: {
    'Content-Type': 'application/json',
  },
})

api.interceptors.request.use((config) => {
  const token = useAuthStore.getState().token
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

export default api
```

## 8. 배포

### 8.1 S3 + CloudFront
- `npm run build` → Static Export
- S3 Bucket에 업로드
- CloudFront CDN

### 8.2 Docker
- Multi-stage build
- Node.js Alpine

## 9. 실행

```bash
# Development
npm run dev

# Build
npm run build

# Export
npm run export
```