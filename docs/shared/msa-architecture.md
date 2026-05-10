# MSA 서비스 분리 전략

## 1. 서비스 분리 원칙

### 도메인 주도 설계 (DDD)
- 비즈니스 도메인별 서비스 분리
- 바운디드 컨텍스트 명확히 정의
- 서비스 간 느슨한 결합, 높은 응집도

### 데이터 분리
- 각 서비스는 자신의 데이터베이스 소유
- 데이터 동기화는 이벤트 기반 아키텍처 사용
- 분산 트랜잭션 최소화

## 2. 서비스 구성도

```
┌─────────────────────────────────────────────────────────────────┐
│                          API Gateway                             │
│              (인증, 라우팅, 로깅, Rate Limiting)                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┴─────────────┐
                │                           │
    ┌───────────▼──────────┐    ┌──────────▼──────────┐
    │   온프레미스 환경      │    │   클라우드 환경       │
    └───────────┬──────────┘    └──────────┬──────────┘
                │                           │
    ┌───────────┴──────────┐    ┌──────────┴──────────┐
    │                       │    │                     │
┌───▼────┐           ┌─────▼───┐│ ┌────▼─────┐  ┌────▼─────┐
│ Employee│           │  Auth   ││ │ Product  │  │  Order   │
│Service  │           │ Service ││ │ Service  │  │ Service  │
└───┬─────┘           └─────┬───┘│ └────┬─────┘  └────┬─────┘
    │                       │    │      │             │
    │                       │    │  ┌───▼──────┐      │
    │                       │    │  │  Point   │      │
    │                       │    │  │ Service  │      │
    │                       │    │  └───┬──────┘      │
    │                       │    │      │             │
┌───▼────────┐      ┌──────▼────┴──┴──────▼─────────────▼────┐
│  MySQL MHA │      │         Message Queue (RabbitMQ)        │
│(온프레미스) │      └───────────────────────┬─────────────────┘
└────────────┘                              │
                                 ┌───────────▼───────────┐
                                 │     AWS RDS MySQL     │
                                 │     (클라우드)         │
                                 └───────────────────────┘
```

## 3. 서비스 상세

### 3.1 사원관리 시스템 (온프레미스)

#### Employee Service (사원 서비스)
**책임:**
- 사원 정보 CRUD
- 조직도 관리 (부서, 팀, 직급)
- 사원 검색 및 필터링
- 사원 상태 관리 (재직, 휴직, 퇴사)

**API Endpoints:**
```
POST   /api/employees              # 사원 등록
GET    /api/employees              # 사원 목록 조회
GET    /api/employees/:id          # 사원 상세 조회
PUT    /api/employees/:id          # 사원 정보 수정
DELETE /api/employees/:id          # 사원 삭제
GET    /api/employees/search       # 사원 검색
GET    /api/organization/chart     # 조직도 조회
```

**데이터베이스 스키마:**
```sql
employees (
  id, employee_number, name, email, phone,
  department_id, position, rank, hire_date, status,
  created_at, updated_at
)

departments (
  id, name, parent_id, manager_id, created_at
)
```

**이벤트:**
- EmployeeCreated
- EmployeeUpdated
- EmployeeDeleted
- DepartmentChanged

#### Auth Service (인증 서비스)
**책임:**
- 사용자 인증 (로그인/로그아웃)
- JWT 토큰 발급 및 검증
- 권한 관리 (RBAC)
- 세션 관리

**API Endpoints:**
```
POST   /api/auth/login             # 로그인
POST   /api/auth/logout            # 로그아웃
POST   /api/auth/refresh           # 토큰 갱신
GET    /api/auth/verify            # 토큰 검증
POST   /api/auth/password/reset    # 비밀번호 재설정
GET    /api/auth/permissions       # 권한 조회
```

**데이터베이스 스키마:**
```sql
users (
  id, employee_id, username, password_hash,
  role, status, last_login, created_at
)

roles (
  id, name, description, permissions, created_at
)

permissions (
  id, name, resource, action, created_at
)
```

**이벤트:**
- UserLoggedIn
- UserLoggedOut
- TokenRefreshed
- PasswordReset

### 3.2 복지포인트몰 시스템 (클라우드)

#### Product Service (상품 서비스)
**책임:**
- 상품 등록/조회/수정/삭제
- 카테고리 관리
- 상품 재고 관리
- 상품 검색 및 필터링

**API Endpoints:**
```
POST   /api/products               # 상품 등록
GET    /api/products               # 상품 목록 조회
GET    /api/products/:id           # 상품 상세 조회
PUT    /api/products/:id           # 상품 정보 수정
DELETE /api/products/:id           # 상품 삭제
GET    /api/products/search        # 상품 검색
GET    /api/categories             # 카테고리 조회
POST   /api/categories             # 카테고리 등록
```

**데이터베이스 스키마:**
```sql
products (
  id, name, description, price, stock,
  category_id, image_url, status, created_at, updated_at
)

categories (
  id, name, parent_id, created_at
)

product_images (
  id, product_id, image_url, order
)
```

**이벤트:**
- ProductCreated
- ProductUpdated
- ProductDeleted
- StockUpdated

#### Order Service (주문 서비스)
**책임:**
- 주문 생성/조회/취소
- 주문 상태 관리
- 배송 정보 관리
- 주문 이력 관리

**API Endpoints:**
```
POST   /api/orders                 # 주문 생성
GET    /api/orders                 # 주문 목록 조회
GET    /api/orders/:id             # 주문 상세 조회
PUT    /api/orders/:id/cancel      # 주문 취소
PUT    /api/orders/:id/status      # 주문 상태 변경
GET    /api/orders/history/:userId # 사용자별 주문 이력
```

**데이터베이스 스키마:**
```sql
orders (
  id, user_id, total_amount, status,
  shipping_address, created_at, updated_at
)

order_items (
  id, order_id, product_id, quantity, price
)

shipping_info (
  id, order_id, recipient, address, phone, tracking_number
)
```

**이벤트:**
- OrderCreated
- OrderCancelled
- OrderStatusChanged
- PaymentProcessed

#### Point Service (포인트 서비스)
**책임:**
- 포인트 충전/사용/조회
- 포인트 이력 관리
- 월별 포인트 지급
- 사원별 포인트 연동 (온프레미스와 통신)

**API Endpoints:**
```
POST   /api/points/charge          # 포인트 충전
POST   /api/points/use              # 포인트 사용
GET    /api/points/balance/:userId  # 포인트 잔액 조회
GET    /api/points/history/:userId  # 포인트 이력 조회
POST   /api/points/monthly-grant   # 월별 포인트 지급
```

**데이터베이스 스키마:**
```sql
points (
  id, user_id, balance, created_at, updated_at
)

point_transactions (
  id, user_id, amount, type, description, created_at
)

monthly_grants (
  id, user_id, amount, granted_at, created_at
)
```

**이벤트:**
- PointCharged
- PointUsed
- MonthlyGrantProcessed
- BalanceUpdated

### 3.3 공통 서비스

#### API Gateway
**책임:**
- 요청 라우팅
- 인증/인가 검증
- Rate Limiting
- 로깅 및 모니터링
- 로드 밸런싱

**기능:**
- 클라이언트 요청을 적절한 서비스로 라우팅
- JWT 토큰 검증 및 사용자 정보 추출
- 요청/응답 로깅
- 서비스 간 통신 중계

#### Config Service (설정 관리)
**책임:**
- 중앙 집중식 설정 관리
- 환경별 설정 분리 (dev, staging, prod)
- 동적 설정 업데이트
- 설정 버전 관리

#### Logging Service (로깅 서비스)
**책임:**
- 분산 로깅 수집
- 로그 집계 및 분석
- S3 주기 백업
- 로그 검색 및 조회

## 4. 서비스 간 통신

### 동기 통신 (HTTP/REST)
- 외부 API 요청
- 실시간 조회가 필요한 경우
- API Gateway → Microservices

### 비동기 통신 (Message Queue)
- 이벤트 기반 통신
- 데이터 동기화
- 서비스 간 느슨한 결합

**RabbitMQ Exchange/Queue 구성:**
```
Exchange: employee.events
  - Queue: employee.created → Point Service
  - Queue: employee.updated → Point Service

Exchange: order.events
  - Queue: order.created → Point Service (포인트 차감)
  - Queue: order.cancelled → Point Service (포인트 환불)

Exchange: point.events
  - Queue: point.used → Order Service (주문 확인)
  - Queue: point.charged → Notification Service
```

## 5. 데이터 일관성 전략

### Saga Pattern
- 분산 트랜잭션 관리
- 보상 트랜잭션 (Compensating Transaction)
- 결과적 일관성 (Eventual Consistency)

### 예시: 주문 생성 Saga
```
1. Order Service: 주문 생성 (PENDING)
2. Point Service: 포인트 차감
   - 성공: Order Service: 주문 확정 (CONFIRMED)
   - 실패: Order Service: 주문 취소 (CANCELLED)
3. 재고 확인 (Product Service)
   - 성공: 배송 정보 생성
   - 실패: 포인트 환불, 주문 취소
```

## 6. 배포 전략

### 컨테이너화
- Docker 이미지 빌드
- Harbor 레지스트리 저장

### Kubernetes 배포
- Deployment, Service, Ingress
- ConfigMap, Secret
- Horizontal Pod Autoscaler

### 환경 분리
- Development (개발)
- Staging (스테이징)
- Production (운영)

## 7. 모니터링 및 로깅

### 메트릭 수집
- Prometheus: 메트릭 수집
- Grafana: 시각화 대시보드

### 로깅
- ELK Stack / Loki: 로그 수집 및 분석
- S3: 로그 백업

### 분산 추적
- Jaeger / Zipkin: 요청 추적
- OpenTelemetry: 표준화된 추적