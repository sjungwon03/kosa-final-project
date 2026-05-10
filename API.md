# KOSA 사원 관리 시스템 API 문서

## Base URL
- Production: `https://api.kosa.com`
- Development: `http://localhost:8000`

## 인증
대부분의 엔드포인트는 JWT 토큰이 필요합니다.

### 로그인
```http
POST /api/v1/employees/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password"
}
```

응답:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

## 사원 관리 API

### 사원 목록 조회
```http
GET /employee/api/v1/employees?skip=0&limit=100
Authorization: Bearer {token}
```

### 사원 상세 조회
```http
GET /employee/api/v1/employees/{employee_id}
Authorization: Bearer {token}
```

### 사원 생성
```http
POST /employee/api/v1/employees
Content-Type: application/json

{
  "employee_id": "EMP001",
  "name": "홍길동",
  "email": "hong@example.com",
  "department": "개발팀",
  "position": "시니어 개발자",
  "phone": "010-1234-5678",
  "hire_date": "2024-01-01T00:00:00",
  "password": "password123"
}
```

### 사원 수정
```http
PUT /employee/api/v1/employees/{employee_id}
Content-Type: application/json

{
  "name": "홍길동 (수정)",
  "department": "기술팀"
}
```

### 사원 삭제
```http
DELETE /employee/api/v1/employees/{employee_id}
Authorization: Bearer {token}
```

## 복지 포인트몰 API

### 상품 목록 조회
```http
GET /welfare/api/v1/products?skip=0&limit=100&category=전자기기
Authorization: Bearer {token}
```

### 상품 상세 조회
```http
GET /welfare/api/v1/products/{product_id}
Authorization: Bearer {token}
```

### 상품 생성
```http
POST /welfare/api/v1/products
Content-Type: application/json

{
  "name": "무선 이어폰",
  "description": "노이즈 캔슬링 기능",
  "price": 150000,
  "stock": 100,
  "category": "전자기기",
  "image_url": "https://example.com/image.jpg"
}
```

### 주문 생성
```http
POST /welfare/api/v1/orders
Content-Type: application/json

{
  "employee_id": 1,
  "items": [
    {
      "product_id": 1,
      "quantity": 2
    }
  ],
  "shipping_address": "서울시 강남구 테헤란로 123",
  "phone": "010-1234-5678"
}
```

### 주문 목록 조회
```http
GET /welfare/api/v1/orders?employee_id=1&skip=0&limit=100
Authorization: Bearer {token}
```

### 포인트 적립
```http
POST /welfare/api/v1/points/earn
Content-Type: application/json

{
  "employee_id": 1,
  "amount": 10000,
  "description": "출석 포인트"
}
```

### 포인트 사용
```http
POST /welfare/api/v1/points/use
Content-Type: application/json

{
  "employee_id": 1,
  "amount": 5000,
  "description": "상품 구매"
}
```

### 포인트 내역 조회
```http
GET /welfare/api/v1/points/{employee_id}?skip=0&limit=100
Authorization: Bearer {token}
```

### 총 포인트 조회
```http
GET /welfare/api/v1/points/{employee_id}/total
Authorization: Bearer {token}
```