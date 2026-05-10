# 하이브리드 클라우드 아키텍처 설계 문서

## 1. 개요

### 1.1 프로젝트 목표

하이브리드 클라우드 환경에서 사원관리 시스템과 복지포인트몰 시스템을 구축하여:

- **온프레미스**: 사원관리 시스템 (보안, 데이터 주권)
- **클라우드**: 복지포인트몰 (확장성, 글로벌 서비스)
- **VPN 연결**: 두 환경의 안전한 통신

### 1.2 기술 스택

| 구분 | 온프레미스 | 클라우드 (AWS) |
|------|-----------|----------------|
| **컨테이너 오케스트레이션** | Kubernetes | EKS |
| **컨테이너 레지스트리** | Harbor | Harbor (sync to AWS) |
| **CI/CD** | GitLab | GitLab Runner |
| **데이터베이스** | MySQL MHA | RDS MySQL |
| **로깅** | ELK Stack | S3 Backup |
| **모니터링** | Prometheus/Grafana | Prometheus/Grafana |
| **IaC** | Terraform | Terraform |

## 2. 아키텍처 구성

### 2.1 전체 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                        하이브리드 클라우드                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────┐      ┌─────────────────────┐          │
│  │   온프레미스 환경     │      │   AWS 클라우드 환경   │          │
│  ├─────────────────────┤      ├─────────────────────┤          │
│  │                     │      │                     │          │
│  │  ┌───────────────┐ │      │ ┌───────────────┐ │          │
│  │  │   GitLab      │ │      │ │    EKS        │ │          │
│  │  │  (CI/CD)      │ │      │ │  Cluster      │ │          │
│  │  └───────────────┘ │      │ └───────────────┘ │          │
│  │                     │      │                     │          │
│  │  ┌───────────────┐ │      │ ┌───────────────┐ │          │
│  │  │   Harbor      │ │      │ │   Product     │ │          │
│  │  │  Registry     │ │      │ │   Service     │ │          │
│  │  └───────────────┘ │      │ └───────────────┘ │          │
│  │                     │      │                     │          │
│  │  ┌───────────────┐ │      │ ┌───────────────┐ │          │
│  │  │ Kubernetes    │ │      │ │   Order       │ │          │
│  │  │  Cluster      │ │      │ │   Service     │ │          │
│  │  └───────────────┘ │      │ └───────────────┘ │          │
│  │                     │      │                     │          │
│  │  ┌───────────────┐ │      │ ┌───────────────┐ │          │
│  │  │ Employee      │ │      │ │   Point       │ │          │
│  │  │ Service       │ │◄────►│ │   Service     │ │          │
│  │  └───────────────┘ │ VPN  │ └───────────────┘ │          │
│  │                     │      │                     │          │
│  │  ┌───────────────┐ │      │ ┌───────────────┐ │          │
│  │  │ MySQL MHA     │ │      │ │   RDS MySQL   │ │          │
│  │  │ (Master-Slave)│ │      │ │  (Multi-AZ)   │ │          │
│  │  └───────────────┘ │      │ └───────────────┘ │          │
│  │                     │      │                     │          │
│  │                     │      │ ┌───────────────┐ │          │
│  │                     │      │ │   S3 Bucket   │ │          │
│  │                     │      │ │ (Log Backup)  │ │          │
│  │                     │      │ └───────────────┘ │          │
│  └─────────────────────┘      └─────────────────────┘          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 네트워크 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                         VPN 연결                                 │
│                                                                 │
│  온프레미스                     AWS VPC                          │
│  (192.168.1.0/24)              (10.0.0.0/16)                     │
│                                                                 │
│  ┌─────────────┐              ┌─────────────┐                  │
│  │   VPN GW    │◄────────────►│  VPN GW     │                  │
│  │  (On-prem)  │   Site-to-   │   (AWS)     │                  │
│  │             │    Site VPN  │             │                  │
│  └─────────────┘              └─────────────┘                  │
│                                                                 │
│  Routing Table:                                                 │
│  - On-prem → AWS: 10.0.0.0/16 via VPN GW                        │
│  - AWS → On-prem: 192.168.1.0/24 via VPN GW                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.3 MSA 서비스 구성

#### 온프레미스 서비스

```
┌─────────────────────────────────────────────┐
│         사원관리 시스템 (온프레미스)           │
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────────┐  ┌─────────────────┐ │
│  │ Employee Service│  │  Auth Service   │ │
│  │                 │  │                 │ │
│  │ - 사원 CRUD     │  │ - JWT Auth      │ │
│  │ - 조직도 관리   │  │ - RBAC          │ │
│  │ - 사원 검색     │  │ - Session       │ │
│  └─────────────────┘  └─────────────────┘ │
│                                             │
│  ┌─────────────────┐  ┌─────────────────┐ │
│  │  MySQL MHA      │  │   RabbitMQ      │ │
│  │  - Master       │  │  - Event Bus    │ │
│  │  - Slave        │  │  - Messaging    │ │
│  └─────────────────┘  └─────────────────┘ │
│                                             │
└─────────────────────────────────────────────┘
```

#### 클라우드 서비스

```
┌─────────────────────────────────────────────┐
│         복지포인트몰 (AWS 클라우드)            │
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────────┐  ┌─────────────────┐ │
│  │ Product Service │  │  Order Service  │ │
│  │                 │  │                 │ │
│  │ - 상품 CRUD     │  │ - 주문 관리     │ │
│  │ - 카테고리      │  │ - 배송 정보     │ │
│  │ - 재고 관리     │  │ - 주문 이력     │ │
│  └─────────────────┘  └─────────────────┘ │
│                                             │
│  ┌─────────────────┐  ┌─────────────────┐ │
│  │  Point Service  │  │   API Gateway   │ │
│  │                 │  │                 │ │
│  │ - 포인트 충전   │  │ - 라우팅       │ │
│  │ - 포인트 사용   │  │ - Auth         │ │
│  │ - 이력 관리     │  │ - Rate Limit   │ │
│  └─────────────────┘  └─────────────────┘ │
│                                             │
│  ┌─────────────────┐  ┌─────────────────┐ │
│  │   RDS MySQL     │  │   S3 Bucket     │ │
│  │  - Multi-AZ     │  │  - Log Backup   │ │
│  │  - Auto Backup  │  │  - 90 days      │ │
│  └─────────────────┘  └─────────────────┘ │
│                                             │
└─────────────────────────────────────────────┘
```

## 3. 데이터베이스 설계

### 3.1 온프레미스 DB (MySQL MHA)

```
┌─────────────────────────────────────────────┐
│              MySQL MHA 구성                  │
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────────┐                        │
│  │  Master Node    │ (Primary)             │
│  │  - Write Ops    │                        │
│  │  - 192.168.1.10 │                        │
│  └─────────────────┘                        │
│          │                                  │
│          │ Replication                      │
│          ▼                                  │
│  ┌─────────────────┐  ┌─────────────────┐ │
│  │  Slave Node 1   │  │  Slave Node 2   │ │
│  │  - Read Ops     │  │  - Read Ops     │ │
│  │  - 192.168.1.11 │  │  - 192.168.1.12 │ │
│  │  (Candidate)    │  │  (Backup)       │ │
│  └─────────────────┘  └─────────────────┘ │
│                                             │
│  ┌─────────────────┐                        │
│  │   MHA Manager   │                        │
│  │  - Monitor      │                        │
│  │  - Failover     │                        │
│  └─────────────────┘                        │
│                                             │
└─────────────────────────────────────────────┘
```

**스키마:**

```sql
employees (
  id, employee_number, name, email, phone,
  department_id, position, rank, hire_date, status
)

departments (
  id, name, parent_id, manager_id
)

users (
  id, employee_id, username, password_hash,
  role, status, last_login
)

roles (
  id, name, description, permissions
)
```

### 3.2 클라우드 DB (RDS MySQL)

```
┌─────────────────────────────────────────────┐
│               RDS Multi-AZ                   │
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────────┐                        │
│  │  Primary AZ     │ (ap-northeast-2a)     │
│  │  - Write/Read   │                        │
│  │  - Endpoint     │                        │
│  └─────────────────┘                        │
│          │                                  │
│          │ Replication                      │
│          ▼                                  │
│  ┌─────────────────┐                        │
│  │  Standby AZ     │ (ap-northeast-2b)     │
│  │  - Failover     │                        │
│  └─────────────────┘                        │
│                                             │
│  ┌─────────────────┐                        │
│  │  Read Replica   │ (Optional)            │
│  │  - Read Scaling │                        │
│  └─────────────────┘                        │
│                                             │
└─────────────────────────────────────────────┘
```

**스키마:**

```sql
products (
  id, name, description, price, stock,
  category_id, image_url, status
)

categories (
  id, name, parent_id
)

orders (
  id, user_id, total_amount, status,
  shipping_address
)

order_items (
  id, order_id, product_id, quantity, price
)

points (
  id, user_id, balance
)

point_transactions (
  id, user_id, amount, type, description
)
```

## 4. CI/CD 파이프라인

### 4.1 GitLab CI/CD Flow

```
┌─────────────────────────────────────────────┐
│           GitLab CI/CD Pipeline              │
├─────────────────────────────────────────────┤
│                                             │
│  Code Push                                   │
│      │                                       │
│      ▼                                       │
│  ┌─────────────────┐                        │
│  │   Test Stage    │                        │
│  │  - Unit Tests   │                        │
│  │  - E2E Tests    │                        │
│  │  - Lint         │                        │
│  └─────────────────┘                        │
│      │                                       │
│      ▼                                       │
│  ┌─────────────────┐                        │
│  │   Build Stage   │                        │
│  │  - Docker Build │                        │
│  │  - Push Harbor  │                        │
│  └─────────────────┘                        │
│      │                                       │
│      ▼                                       │
│  ┌─────────────────┐                        │
│  │  Deploy Stage   │                        │
│  │                 │                        │
│  │  ┌───────────┐ │                        │
│  │  │ On-prem   │ │ (Employee Service)     │
│  │  │ Kubectl   │ │                        │
│  │  └───────────┘ │                        │
│  │                 │                        │
│  │  ┌───────────┐ │                        │
│  │  │ EKS       │ │ (Welfare Services)     │
│  │  │ Kubectl   │ │                        │
│  │  └───────────┘ │                        │
│  └─────────────────┘                        │
│      │                                       │
│      ▼                                       │
│  ┌─────────────────┐                        │
│  │  Notify Stage   │                        │
│  │  - Slack       │                        │
│  │  - Email       │                        │
│  └─────────────────┘                        │
│                                             │
└─────────────────────────────────────────────┘
```

### 4.2 Harbor Registry Flow

```
┌─────────────────────────────────────────────┐
│           Harbor Registry                    │
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────────┐                        │
│  │  GitLab Runner  │                        │
│  │  - Build Image  │                        │
│  └─────────────────┘                        │
│      │                                       │
│      ▼                                       │
│  ┌─────────────────┐                        │
│  │    Harbor       │                        │
│  │  - Scan Image   │                        │
│  │  - Tag Version  │                        │
│  │  - Store Image  │                        │
│  └─────────────────┘                        │
│      │                                       │
│      ├──────────────────┐                   │
│      │                  │                   │
│      ▼                  ▼                   │
│  ┌─────────────────┐  ┌─────────────────┐ │
│  │  On-prem K8s    │  │     EKS         │ │
│  │  - Pull Image   │  │  - Pull Image   │ │
│  │  - Deploy       │  │  - Deploy       │ │
│  └─────────────────┘  └─────────────────┘ │
│                                             │
└─────────────────────────────────────────────┘
```

## 5. 모니터링 및 로깅

### 5.1 Prometheus + Grafana

```
┌─────────────────────────────────────────────┐
│         Monitoring Stack                     │
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────────┐                        │
│  │  Prometheus     │                        │
│  │  - Metrics      │                        │
│  │  - Alerting     │                        │
│  └─────────────────┘                        │
│      │                                       │
│      │ Scrape                                │
│      ├──────────────────┐                   │
│      │                  │                   │
│      ▼                  ▼                   │
│  ┌─────────────────┐  ┌─────────────────┐ │
│  │  Node Exporter  │  │   App Metrics   │ │
│  │  - CPU/Memory   │  │  - Custom       │ │
│  │  - Disk/Network │  │  - Business     │ │
│  └─────────────────┘  └─────────────────┘ │
│                                             │
│  ┌─────────────────┐                        │
│  │    Grafana      │                        │
│  │  - Dashboards   │                        │
│  │  - Visualization│                        │
│  └─────────────────┘                        │
│                                             │
└─────────────────────────────────────────────┘
```

### 5.2 로깅 및 S3 백업

```
┌─────────────────────────────────────────────┐
│         Logging Architecture                 │
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────────┐                        │
│  │  Applications   │                        │
│  │  - Winston      │                        │
│  │  - Structured   │                        │
│  └─────────────────┘                        │
│      │                                       │
│      ▼                                       │
│  ┌─────────────────┐                        │
│  │  Log Buffer     │                        │
│  │  - 100 entries  │                        │
│  │  - 1 min flush  │                        │
│  └─────────────────┘                        │
│      │                                       │
│      ▼                                       │
│  ┌─────────────────┐                        │
│  │    S3 Bucket    │                        │
│  │  - Log Archive  │                        │
│  │  - 90 days TTL  │                        │
│  │  - IA/Glacier   │                        │
│  └─────────────────┘                        │
│                                             │
│  ┌─────────────────┐                        │
│  │  CronJob        │                        │
│  │  - Daily Backup │                        │
│  │  - 2 AM         │                        │
│  └─────────────────┘                        │
│                                             │
└─────────────────────────────────────────────┘
```

## 6. 보안 아키텍처

### 6.1 네트워크 보안

```
┌─────────────────────────────────────────────┐
│         Network Security                     │
├─────────────────────────────────────────────┤
│                                             │
│  VPN Connection                              │
│  - IPsec Encryption                          │
│  - IKEv2 Protocol                            │
│  - Pre-shared Key                            │
│                                             │
│  VPC Security Groups                         │
│  - Ingress: Required ports only             │
│  - Egress: Restricted                       │
│                                             │
│  Network Policies (K8s)                      │
│  - Pod-to-Pod communication                 │
│  - Namespace isolation                       │
│                                             │
│  TLS/SSL                                     │
│  - Let's Encrypt                             │
│  - Ingress TLS                               │
│                                             │
└─────────────────────────────────────────────┘
```

### 6.2 인증 및 권한

```
┌─────────────────────────────────────────────┐
│         Authentication & Authorization       │
├─────────────────────────────────────────────┤
│                                             │
│  JWT Authentication                          │
│  - RS256 Signature                           │
│  - 1 hour expiration                         │
│  - Refresh token                             │
│                                             │
│  RBAC (Role-Based Access Control)           │
│  - Admin: Full access                       │
│  - Manager: Department scope                │
│  - Employee: Read own data                  │
│                                             │
│  Kubernetes RBAC                             │
│  - ServiceAccounts                          │
│  - ClusterRoles                             │
│  - RoleBindings                             │
│                                             │
│  AWS IAM                                     │
│  - IAM Roles for Service Accounts           │
│  - Least privilege principle                │
│                                             │
└─────────────────────────────────────────────┘
```

## 7. 용량 및 확장성

### 7.1 리소스 계획

| 서비스 | Min Pods | Max Pods | CPU Request | Memory Request |
|--------|----------|----------|-------------|----------------|
| Employee Service | 3 | 10 | 250m | 256Mi |
| Auth Service | 2 | 5 | 200m | 200Mi |
| Product Service | 3 | 15 | 250m | 256Mi |
| Order Service | 3 | 15 | 300m | 300Mi |
| Point Service | 3 | 10 | 250m | 256Mi |

### 7.2 Node Group 계획

| Environment | Node Type | Min Nodes | Max Nodes | Usage |
|-------------|-----------|-----------|-----------|-------|
| On-prem | N/A | 5 | N/A | Employee services |
| EKS General | m5.large | 3 | 5 | Core services |
| EKS Compute | c5.large | 2 | 10 | Batch jobs |

## 8. 비용 최적화

### 8.1 AWS 리소스 비용

| Service | Configuration | Estimated Monthly Cost |
|---------|---------------|------------------------|
| EKS | 5 nodes (m5.large) | $500 |
| RDS | db.t3.medium Multi-AZ | $150 |
| S3 | 100GB logs | $5 |
| VPN | 2 tunnels | $50 |
| **Total** | | **~$705/month** |

### 8.2 비용 절감 방안

- Spot Instances for compute nodes
- S3 Intelligent Tiering
- Right-sizing pods
- Reserved instances (RDS)

## 9. 장애 대응

### 9.1 페일오버 시나리오

```
┌─────────────────────────────────────────────┐
│         Failover Procedures                  │
├─────────────────────────────────────────────┤
│                                             │
│  MySQL MHA Failover                          │
│  - MHA Manager detects failure              │
│  - Promotes Slave1 to Master                │
│  - Updates DNS/routing                      │
│  - Time: < 30 seconds                       │
│                                             │
│  RDS Multi-AZ Failover                       │
│  - AWS detects failure                      │
│  - Promotes Standby to Primary              │
│  - Endpoint unchanged                       │
│  - Time: < 2 minutes                        │
│                                             │
│  Kubernetes Pod Failover                     │
│  - ReplicaSet maintains replicas           │
│  - New pod created automatically           │
│  - HPA scales up                            │
│  - Time: < 1 minute                         │
│                                             │
│  VPN Tunnel Failover                         │
│  - Second tunnel activates                  │
│  - BGP reroutes                             │
│  - Time: < 5 seconds                        │
│                                             │
└─────────────────────────────────────────────┘
```

### 9.2 백업 및 복구

```
┌─────────────────────────────────────────────┐
│         Backup Strategy                      │
├─────────────────────────────────────────────┤
│                                             │
│  Database Backup                             │
│  - Daily: mysqldump (On-prem)               │
│  - Automated: RDS snapshots (7 days)        │
│  - Monthly: Full backup to S3               │
│                                             │
│  Application Backup                          │
│  - Container images in Harbor               │
│  - Git repository (GitLab)                  │
│                                             │
│  Configuration Backup                        │
│  - Terraform state                          │
│  - K8s manifests                            │
│  - Environment variables                    │
│                                             │
│  Recovery Time Objective (RTO)              │
│  - Database: < 1 hour                       │
│  - Application: < 15 minutes                │
│                                             │
│  Recovery Point Objective (RPO)             │
│  - Database: < 24 hours                     │
│  - Logs: < 1 minute                         │
│                                             │
└─────────────────────────────────────────────┘
```

## 10. 향후 계획

### 10.1 Phase 1 (현재)
- 기본 MSA 구성
- 하이브리드 클라우드 VPN 연결
- CI/CD 파이프라인
- 모니터링/로깅

### 10.2 Phase 2 (3개월)
- Service Mesh (Istio)
- API Gateway 상세 구현
- 이벤트 소싱 패턴
- CQRS 적용

### 10.3 Phase 3 (6개월)
- Multi-region deployment
- Global load balancing
- Disaster recovery site
- Advanced security (Vault)

## 11. 결론

이 하이브리드 클라우드 아키텍처는:

- **보안**: 온프레미스에서 민감 데이터 관리
- **확장성**: 클라우드에서 글로벌 서비스 제공
- **안정성**: MHA + Multi-AZ 고가용성
- **효율성**: CI/CD 자동화, 모니터링

Terraform, Kubernetes, GitLab을 통한 완전한 DevOps 환경을 제공합니다.