# KOSA 사원 관리 및 복지 포인트몰 시스템

## 1. 시스템 개요

### 1.1 목적
KOSA 시스템은 사원 관리와 복지 포인트몰을 통합한 MSA(Microservices Architecture) 기반 시스템입니다. 클라우드 버스팅을 통해 온프레미스와 AWS를 연동하여 트래픽 급증 시 자동으로 AWS로 확장합니다.

### 1.2 주요 기능
- **사원 관리**: 사원 등록, 수정, 삭제, 조회, 인증
- **복지 포인트몰**: 상품 관리, 주문 처리, 포인트 적립/사용
- **클라우드 버스팅**: 온프레미스 부하 시 AWS 자동 확장

### 1.3 기술 스택
- **Frontend**: React 18, Next.js 14, shadcn/ui, Tailwind CSS
- **Backend**: FastAPI, Python 3.11
- **Database**: MySQL 8.0 (MHA), Redis
- **Infrastructure**: Kubernetes, Docker, Terraform
- **Multi-Cluster**: Kubernetes Federation v2

## 2. 아키텍처

### 2.1 전체 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│                    Users (Internet)                      │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│              S3 + CloudFront (Frontend)                  │
│            React Static Website (CDN)                   │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│                  Load Balancer                          │
│                 (Public VLAN 100)                       │
└─────────────┬───────────────────────┬───────────────────┘
              │                       │
              ▼                       ▼
┌─────────────────────┐   ┌───────────────────────────────┐
│   온프레미스 K8s     │   │        AWS EKS                 │
│  (Private VLAN 200) │   │   (CloudBursting용)            │
│                     │   │                                │
│  ┌──────────────┐   │   │  ┌──────────────┐             │
│  │ API Gateway  │   │   │  │ API Gateway  │             │
│  │  (2-20 pods) │   │   │  │  (0-100 pods)│             │
│  └──────┬───────┘   │   │  └──────┬───────┘             │
│         │           │   │         │                     │
│  ┌──────┴───────┐   │   │  ┌──────┴───────┐             │
│  │Employee Svc  │   │   │  │Employee Svc  │             │
│  │Welfare Svc   │   │   │  │Welfare Svc   │             │
│  └──────┬───────┘   │   │  └──────┬───────┘             │
│         │           │   │         │                     │
│  ┌──────┴───────┐   │   │  ┌──────┴───────┐             │
│  │   Redis      │   │   │  │ ElastiCache  │             │
│  └──────┬───────┘   │   │  └──────┬───────┘             │
│         │           │   │         │                     │
└─────────┼───────────┘   └─────────┼─────────────────────┘
          │                         │
          ▼                         ▼
┌─────────────────────┐   ┌───────────────────────────────┐
│  MySQL MHA Cluster  │   │   Amazon Aurora MySQL         │
│  (Private VLAN 300) │   │   (Active-Standby)            │
│                     │   │                                │
│  ┌──────────────┐   │   │  ┌──────────────┐             │
│  │   Master     │───┼───┼─▶│   Primary    │             │
│  │  (Active)    │   │   │  │              │             │
│  └──────┬───────┘   │   │  └──────┬───────┘             │
│         │           │   │         │                     │
│  ┌──────┴───────┐   │   │  ┌──────┴───────┐             │
│  │   Slave 1    │   │   │  │   Replica 1  │             │
│  │   Slave 2    │   │   │  │   Replica 2  │             │
│  └──────────────┘   │   │  └──────────────┘             │
└─────────────────────┘   └───────────────────────────────┘
```

### 2.2 네트워크 구성 (Proxmox VLAN)

| VLAN ID  | 이름      | CIDR         | 용도                    |
|----------|-----------|--------------|-------------------------|
| 100      | Public    | 10.0.1.0/24  | 외부 요청 (Load Balancer)|
| 200      | K8s       | 10.0.2.0/24  | Kubernetes 클러스터      |
| 300      | DB        | 10.0.3.0/24  | MySQL MHA, Redis        |

### 2.3 Proxmox 클러스터 구성

- **노드**: 4개 (pve1, pve2, pve3, pve4)
- **K8s Master**: 3개 (2 CPU, 4GB RAM)
- **K8s Worker**: 6개 (4 CPU, 8GB RAM)
- **MySQL MHA**: 3개 (2 CPU, 4GB RAM)

### 2.4 AWS 클러스터 구성

- **EKS**: Managed Node Groups + Fargate
- **VPN**: Site-to-Site VPN to On-premise DB
  - AWS VPN Gateway ↔ 온프레미스 VPN Gateway (10.0.1.1)
  - 온프레미스 MySQL MHA 직접 접근 (10.0.3.10)
- **ElastiCache**: Redis 7.0 (2 nodes)
- **S3 + CloudFront**: Frontend CDN
- **No Aurora**: VPN으로 온프레미스 MySQL MHA 사용 (비용 절감)

## 3. 서비스 구성

### 3.1 API Gateway
- **기능**: 요청 라우팅, CORS, 인증 처리
- **포트**: 8000
- **Replicas**: 온프레미스 2-20, AWS 0-100

### 3.2 Employee Service
- **기능**: 사원 CRUD, JWT 인증
- **포트**: 8001
- **Replicas**: 온프레미스 2-15, AWS 0-200

### 3.3 Welfare Service
- **기능**: 상품, 주문, 포인트 관리
- **포트**: 8002
- **Replicas**: 온프레미스 2-15, AWS 0-200

## 4. 데이터베이스 구성

### 4.1 MySQL MHA (온프레미스 + VPN)
- **Master**: Active (10.0.3.10)
- **Slave 1**: Standby (10.0.3.11)
- **Slave 2**: Standby (10.0.3.12)
- **복제**: GTID-based, Row-based binlog
- **VPN 연결**: AWS EKS → 온프레미스 MySQL (VPN Tunnel)

### 4.2 Redis / ElastiCache
- **온프레미스**: Redis Cluster (10.0.3.x)
- **AWS**: ElastiCache Cluster Mode

## 5. 클라우드 버스팅

### 5.1 동작 방식
1. 온프레미스 CPU 사용률 70% 초과
2. CloudWatch Alarm 트리거
3. AWS EKS Node Group replicas 증가 (0 → 10+)
4. Kubernetes Federation으로 서비스 연동
5. 트래픽 감소 시 replicas 감소

### 5.2 Kubernetes Federation v2
- **ServiceExport**: 서비스 멀티클러스터 등록
- **ServiceImport**: 다른 클러스터 서비스 접근
- **EndpointSlice**: 멀티클러스터 엔드포인트 관리

## 6. CI/CD 구성

### 6.1 GitLab
- **URL**: http://gitlab.kosa.local
- **Runner**: Kubernetes Executor (2 replicas)

### 6.2 Harbor Registry
- **URL**: http://harbor.kosa.local
- **Project**: kosa
- **Images**: api-gateway, employee-service, welfare-service

### 6.3 Pipeline
- **Build**: Docker Image Build → Harbor Push
- **Test**: pytest
- **Deploy**: Kubernetes Rolling Update

## 7. 배포 방식

### 7.1 Helm Chart
- **Chart**: `kosa-stack`
- **Values**: values.yaml (기본), values-onprem.yaml (온프레미스), values-aws.yaml (AWS)

### 7.2 Terraform
- **Proxmox**: VM 생성, VLAN 설정
- **AWS**: VPC, EKS, RDS, ElastiCache, S3, CloudFront

## 8. VPN 연동

### 8.1 AWS VPN Gateway
- Site-to-Site VPN (IPsec)
- 온프레미스 VPN Gateway: 10.0.1.1

### 8.2 네트워크 라우팅
- AWS → 온프레미스: 10.0.0.0/8 via VPN
- 온프레미스 → AWS: 10.1.0.0/16 via VPN

### 8.3 DB 접근
- AWS EKS → 온프레미스 MySQL (10.0.3.10)
- VPN Tunnel로 안전한 연결

## 9. 모니터링

## 9. 모니터링

### 9.1 CloudWatch Dashboard
- EKS CPU/Memory 사용률
- RDS Connections, CPU
- Redis Cache Hits, Memory

### 9.2 CloudWatch Alarms
- CPU High (70%): AWS 확장 트리거
- CPU Low (30%): AWS replicas 감소