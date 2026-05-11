# Employee Service (사원관리 서비스)

## 1. 개요

사원의 CRUD(Create, Read, Update, Delete) 및 인증 기능을 제공하는 마이크로서비스입니다.

## 2. 기능

### 2.1 사원 관리
- 사원 등록 (POST /api/v1/employees)
- 사원 목록 조회 (GET /api/v1/employees)
- 사원 상세 조회 (GET /api/v1/employees/{id})
- 사원 수정 (PUT /api/v1/employees/{id})
- 사원 삭제 (DELETE /api/v1/employees/{id})

### 2.2 인증
- 로그인 (POST /api/v1/employees/login)
- JWT 토큰 발급
- 비밀번호 암호화 (bcrypt)

## 3. 데이터 모델

### 3.1 Employee 테이블

| 필드          | 타입       | 설명               |
|---------------|------------|--------------------|
| id            | INT        | Primary Key        |
| employee_id   | VARCHAR(50)| 사원번호 (unique)  |
| name          | VARCHAR(100)| 이름              |
| email         | VARCHAR(100)| 이메일 (unique)   |
| department    | VARCHAR(100)| 부서              |
| position      | VARCHAR(100)| 직급              |
| phone         | VARCHAR(20)| 전화번호           |
| hire_date     | DATETIME   | 입사일             |
| status        | VARCHAR(20)| 상태 (active, etc) |
| hashed_password| VARCHAR(255)| 암호화된 비밀번호 |
| created_at    | DATETIME   | 생성일             |
| updated_at    | DATETIME   | 수정일             |

## 4. API Endpoints

### 4.1 로그인
```http
POST /api/v1/employees/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password"
}

Response:
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "token_type": "bearer"
}
```

### 4.2 사원 등록
```http
POST /api/v1/employees
Content-Type: application/json

{
  "employee_id": "EMP001",
  "name": "홍길동",
  "email": "hong@example.com",
  "department": "개발팀",
  "position": "시니어 개발자",
  "phone": "010-1234-5678",
  "hire_date": "2024-01-01",
  "password": "password123"
}
```

### 4.3 사원 목록
```http
GET /api/v1/employees?skip=0&limit=100
Authorization: Bearer {token}

Response:
[
  {
    "id": 1,
    "employee_id": "EMP001",
    "name": "홍길동",
    "email": "hong@example.com",
    ...
  }
]
```

## 5. 인증

### 5.1 JWT 토큰
- **Algorithm**: HS256
- **Expiration**: 30 minutes
- **Payload**: email, employee_id

### 5.2 비밀번호 암호화
- **bcrypt** 사용
- Salt 자동 생성

## 6. 환경 변수

| 변수          | 설명           |
|---------------|----------------|
| MYSQL_HOST    | MySQL 호스트   |
| MYSQL_PORT    | MySQL 포트     |
| MYSQL_USER    | MySQL 사용자   |
| MYSQL_PASSWORD| MySQL 비밀번호 |
| MYSQL_DATABASE| Database 이름  |
| REDIS_HOST    | Redis 호스트   |
| REDIS_PORT    | Redis 포트     |

## 7. 배포

### 7.1 Kubernetes
- **Deployment**: 2-15 replicas (온프레미스)
- **Service**: ClusterIP (8001)
- **HPA**: CPU 70%

## 8. 테스트

```bash
# Health check
curl http://localhost:8001/health

# 로그인
curl -X POST http://localhost:8001/api/v1/employees/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password"}'
```