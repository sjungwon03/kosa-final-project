# Welfare Service (복지포인트몰 서비스)

## 1. 개요

복지 포인트몰 기능을 제공하는 마이크로서비스입니다. 상품 관리, 주문 처리, 포인트 관리 기능을 포함합니다.

## 2. 기능

### 2.1 상품 관리
- 상품 등록 (POST /api/v1/products)
- 상품 목록 (GET /api/v1/products)
- 상품 상세 (GET /api/v1/products/{id})
- 상품 수정 (PUT /api/v1/products/{id})
- 상품 삭제 (DELETE /api/v1/products/{id})

### 2.2 주문 관리
- 주문 생성 (POST /api/v1/orders)
- 주문 목록 (GET /api/v1/orders)
- 주문 상세 (GET /api/v1/orders/{id})
- 주문 상태 변경 (PUT /api/v1/orders/{id}/status)

### 2.3 포인트 관리
- 포인트 적립 (POST /api/v1/points/earn)
- 포인트 사용 (POST /api/v1/points/use)
- 포인트 내역 (GET /api/v1/points/{employee_id})
- 총 포인트 (GET /api/v1/points/{employee_id}/total)

## 3. 데이터 모델

### 3.1 Product 테이블

| 필드         | 타입          | 설명          |
|--------------|---------------|---------------|
| id           | INT           | Primary Key   |
| name         | VARCHAR(200)  | 상품명        |
| description  | TEXT          | 설명          |
| price        | DECIMAL(10,2) | 가격          |
| stock        | INT           | 재고          |
| category     | VARCHAR(50)   | 카테고리      |
| image_url    | VARCHAR(500)  | 이미지 URL    |

### 3.2 Order 테이블

| 필드             | 타입          | 설명          |
|------------------|---------------|---------------|
| id               | INT           | Primary Key   |
| employee_id      | INT           | 사원 ID       |
| order_number     | VARCHAR(50)   | 주문번호      |
| total_amount     | DECIMAL(10,2) | 총 금액       |
| status           | VARCHAR(20)   | 주문 상태     |
| shipping_address | VARCHAR(500)  | 배송지        |
| phone            | VARCHAR(20)   | 전화번호      |

### 3.3 OrderItem 테이블

| 필드        | 타입          | 설명          |
|-------------|---------------|---------------|
| id          | INT           | Primary Key   |
| order_id    | INT           | 주문 ID       |
| product_id  | INT           | 상품 ID       |
| quantity    | INT           | 수량          |
| price       | DECIMAL(10,2) | 가격          |

### 3.4 Point 테이블

| 필드         | 타입          | 설명          |
|--------------|---------------|---------------|
| id           | INT           | Primary Key   |
| employee_id  | INT           | 사원 ID       |
| amount       | DECIMAL(10,2) | 포인트 금액   |
| type         | VARCHAR(20)   | earn/spend    |
| description  | TEXT          | 설명          |

## 4. API Endpoints

### 4.1 상품 등록
```http
POST /api/v1/products
Content-Type: application/json

{
  "name": "무선 이어폰",
  "description": "노이즈 캔슬링",
  "price": 150000,
  "stock": 100,
  "category": "전자기기",
  "image_url": "https://example.com/image.jpg"
}
```

### 4.2 주문 생성
```http
POST /api/v1/orders
Content-Type: application/json

{
  "employee_id": 1,
  "items": [
    {"product_id": 1, "quantity": 2}
  ],
  "shipping_address": "서울시 강남구",
  "phone": "010-1234-5678"
}
```

### 4.3 포인트 적립
```http
POST /api/v1/points/earn?employee_id=1&amount=10000&description=출석포인트
```

### 4.4 포인트 사용
```http
POST /api/v1/points/use?employee_id=1&amount=5000&description=상품구매
```

## 5. 비즈니스 로직

### 5.1 주문 처리
1. 재고 확인
2. 재고 부족 시 에러 반환
3. 주문 생성
4. 재고 감소
5. 총 금액 계산

### 5.2 포인트 관리
1. 현재 포인트 조회
2. 사용 시 포인트 부족 체크
3. 포인트 내역 기록

## 6. 배포

- **Deployment**: 2-15 replicas
- **Service**: ClusterIP (8002)
- **HPA**: CPU 70%

## 7. 테스트

```bash
# Health check
curl http://localhost:8002/health

# 상품 목록
curl http://localhost:8002/api/v1/products

# 포인트 조회
curl http://localhost:8002/api/v1/points/1/total
```