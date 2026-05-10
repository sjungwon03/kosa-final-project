# KOSA 사원 관리 및 복지 포인트몰 시스템

## 아키텍처

### 클라우드 버스팅 (Multi-Cluster)
- **Primary Cluster**: 온프레미스 (Proxmox + Kubernetes)
  - 4개 노드 (pve1, pve2, pve3, pve4)
  - VLAN SDN 구성
    - VLAN 100: Public (외부 요청)
    - VLAN 200: K8s Private
    - VLAN 300: DB MHA Private
- **Secondary Cluster**: AWS EKS (클라우드 버스팅용)
- **트래픽 분산**: Kubernetes Federation v2
- **Auto-Scaling**: HPA + CloudWatch Alarms

### 컴포넌트
- **프론트엔드**: React + shadcn/ui, S3 + CloudFront 배포
- **백엔드**: FastAPI MSA 구조
  - API Gateway: 라우팅 및 인증 처리
  - 사원관리 서비스: 사원 CRUD 및 인증
  - 복지포인트몰 서비스: 상품, 주문, 포인트 관리
- **온프레미스 DB**: MySQL MHA (Active-Standby) + Redis
- **AWS DB**: Amazon Aurora MySQL + ElastiCache Redis
- **IaC**: Terraform (Proxmox + AWS EKS)

### 문서
- [01-architecture.md](docs/01-architecture.md) - 전체 아키텍처
- [02-api-gateway.md](docs/02-api-gateway.md) - API Gateway 설명
- [03-employee-service.md](docs/03-employee-service.md) - 사원관리 서비스
- [04-welfare-service.md](docs/04-welfare-service.md) - 복지포인트몰 서비스
- [05-frontend.md](docs/05-frontend.md) - Frontend (React + Next.js)
- [06-cloudbursting.md](docs/06-cloudbursting.md) - 클라우드 버스팅
- [07-deployment-guide.md](docs/07-deployment-guide.md) - 배포 가이드
- [08-terraform-guide.md](docs/08-terraform-guide.md) - Terraform IaC
- [09-helm-guide.md](docs/09-helm-guide.md) - Helm Chart
- [10-troubleshooting.md](docs/10-troubleshooting.md) - 문제 해결
- [11-cicd-pipeline.md](docs/11-cicd-pipeline.md) - GitLab CI/CD Pipeline
- [12-vpn-connection.md](docs/12-vpn-connection.md) - VPN 연결 (AWS ↔ 온프레미스)
- [13-gitlab-harbor.md](docs/13-gitlab-harbor.md) - GitLab & Harbor 구성

## 로컬 실행

```bash
# Docker Compose로 전체 시스템 실행
docker-compose up -d

# 서비스 접속
- Frontend: http://localhost:3000
- API Gateway: http://localhost:8000
- Employee Service: http://localhost:8001
- Welfare Service: http://localhost:8002
- MySQL: localhost:3306
- Redis: localhost:6379
```

## Helm 배포 (멀티클러스터)

### 온프레미스 + AWS 클라우드 버스팅
```bash
# 멀티클러스터 배포 (온프레미스 + AWS)
./deploy-multicluster.sh

# 또는 각 클러스터에 개별 배포
helm upgrade --install kosa-stack ./helm-charts/kosa-stack \
  --namespace kosa \
  --create-namespace \
  --values ./helm-charts/kosa-stack/values-onprem.yaml  # 온프레미스용

helm upgrade --install kosa-stack ./helm-charts/kosa-stack \
  --namespace kosa \
  --create-namespace \
  --values ./helm-charts/kosa-stack/values-aws.yaml     # AWS용
```

### 클라우드 버스팅 동작
1. 온프레미스에서 CPU 사용률 70% 초과 시
2. CloudWatch Alarm 트리거
3. AWS EKS 클러스터로 Pod 확장 (replicas 0 → 10+)
4. Istio가 트래픽을 AWS로 분산 (70% 온프레미스, 30% AWS)
5. 트래픽 감소 시 AWS Pod 수 감소

## IaC (Terraform)

### 온프레미스
```bash
# Proxmox VM 생성
cd infrastructure/proxmox
terraform init
terraform apply

# K8s 앱 배포
cd infrastructure/k8s
terraform init
terraform apply

# MySQL MHA 설정
cd infrastructure/mysql-mha
terraform init
terraform apply
```

### AWS EKS + RDS + ElastiCache
```bash
# AWS 인프라 배포
./deploy-aws.sh

# 또는 수동으로 실행
cd infrastructure/aws
terraform init
terraform apply

# Helm 차트까지 자동 배포됨
```

## 프로젝트 구조

```
/
├── frontend/                       # React 프론트엔드
├── backend/                        # FastAPI 백엔드 (MSA)
│   ├── api-gateway/
│   ├── employee-service/
│   ├── welfare-service/
│   └── shared/
├── helm-charts/                    # Helm Charts (클라우드 버스팅)
│   └── kosa-stack/
│       ├── Chart.yaml
│       ├── values.yaml             # 기본 values
│       ├── values-onprem.yaml      # 온프레미스용
│       ├── values-aws.yaml         # AWS용
│       └── templates/              # K8s manifests templates
├── infrastructure/                 # IaC (Terraform)
│   ├── proxmox/                    # 온프레미스 VM
│   ├── k8s/                        # 온프레미스 K8s
│   ├── mysql-mha/                  # MySQL MHA
│   └── aws/                        # AWS EKS + RDS + ElastiCache
├── kubernetes/                     # K8s manifests (단일 클러스터용)
├── kubernetes-multicluster/        # 멀티클러스터 설정
│   ├── federation.yaml             # Kubernetes Federation v2
│   ├── istio-gateway.yaml          # Istio 멀티클러스터
│   └── cloudburst-trigger.yaml     # 클라우드 버스팅 트리거
└── 배포 스크립트
    ├── deploy-multicluster.sh      # 멀티클러스터 배포
    ├── deploy-aws.sh               # AWS 인프라 배포
    └── deploy-s3.sh                # Frontend S3 배포
```