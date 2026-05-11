# API Gateway

## 1. 개요

API Gateway는 모든 클라이언트 요청의 단일 진입점으로, 요청 라우팅, CORS 처리, 인증 등을 수행합니다.

## 2. 기능

### 2.1 요청 라우팅
- `/employee/*` → Employee Service (8001)
- `/welfare/*` → Welfare Service (8002)

### 2.2 CORS
- 모든 origin 허용 (개발용)
- Production에서는 특정 domain만 허용

### 2.3 인증
- JWT 토큰 검증 (미래 기능)

## 3. 구현

### 3.1 코드 (backend/api-gateway/main.py)

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import httpx

app = FastAPI(title="KOSA API Gateway")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "api-gateway"}

@app.api_route("/employee/{path:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def employee_proxy(path: str, request):
    async with httpx.AsyncClient() as client:
        url = f"{settings.employee_service_url}/{path}"
        # Proxy request to employee service
        ...
```

## 4. 환경 변수

| 변수                    | 설명                     | 기본값                        |
|-------------------------|--------------------------|-------------------------------|
| EMPLOYEE_SERVICE_URL    | Employee Service URL     | http://employee-service:8001  |
| WELFARE_SERVICE_URL     | Welfare Service URL      | http://welfare-service:8002   |
| ENV                     | 환경                     | development                   |

## 5. 배포

### 5.1 Dockerfile
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY . .
EXPOSE 8000
CMD ["python", "-m", "uvicorn", "api-gateway.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### 5.2 Kubernetes
- **Deployment**: 2-20 replicas (온프레미스), 0-100 (AWS)
- **Service**: LoadBalancer (MetalLB/NLB)
- **HPA**: CPU 70% 기반 Auto-scaling

## 6. 모니터링

- `/health`: Health Check endpoint
- Prometheus metrics: `/metrics` (미래 기능)