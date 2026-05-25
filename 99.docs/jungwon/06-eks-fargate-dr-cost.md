# EKS Fargate Active-Active Cost Analysis

## Overview

이 문서는 On-prem + EKS Fargate Active-Active 구성의 비용을 분석합니다.

## Architecture (Active-Active)

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS Cloud                             │
│                                                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    NLB (Public)                        │  │
│  │              443 (TLS termination)                     │  │
│  └─────────────────────┬─────────────────────────────────┘  │
│                        │                                     │
│  ┌─────────────────────▼─────────────────────────────────┐  │
│  │              HAProxy (EC2 t3.micro)                    │  │
│  │    roundrobin load balancing:                         │  │
│  │    - onprem:70% weight                                │  │
│  │    - EKS:30% weight                                   │  │
│  └─────────────────────┬─────────────────────────────────┘  │
│                        │                                     │
│            ┌───────────┴───────────┐                         │
│            │                       │                         │
│  Onprem    │              EKS Fargate                        │
│  ┌─────────▼─────────┐   ┌───────▼───────────────────────┐  │
│  │ 172.16.30.205:80  │   │  NLB → kosa/web-app (2 pods)  │  │
│  │ (70% traffic)     │   │  (30% traffic, Fargate)       │  │
│  └───────────────────┘   └───────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## 비용 비교 (월간, ap-northeast-2)

### Active-Active Fargate (현재 구성)

| 항목 | 단위 | 비용 |
|------|------|------|
| EKS Cluster | 1 cluster | $0.10/hr × 24 × 30 = **$72** |
| Fargate Pods | 2 pods × 24hr | $0.04/vCPU-hr × 0.25 × 2 × 24 × 30 = **$14.40** |
| Fargate Memory | 2 pods × 512Mi | $0.00353/GB-hr × 0.5 × 2 × 24 × 30 = **$1.27** |
| NLB (Public) | 1 NLB | $0.0225/hr × 24 × 30 = **$16.20** |
| NLB LCU | ~1000 requests/hr | ~$5-10 |
| VPC NAT Gateway | 2 NAT (HA) | $0.045/hr × 2 × 24 × 30 = **$64.80** |
| Data Transfer | ~10GB/month | ~$1 |

**월간 비용: ~$175-180** (2 pods 24/7 running)

### DR standby (pods=0)

| 항목 | 비용 |
|------|------|
| EKS Cluster | $72 |
| Fargate Pods | $0 |
| NLB | $16.20 |
| NAT Gateway | $64.80 |

**월간 비용: ~$153** (pods=0, standby mode)

### EC2 Node Group (비교)

| 항목 | 비용 |
|------|------|
| EKS Cluster | $72 |
| EC2 t3.small | 2 nodes × $0.034/hr × 24 × 30 = $49 |
| EBS gp3 | 40GB = $3.20 |
| NLB | $16.20 |
| NAT Gateway | $64.80 |

**월간 비용: ~$205**

---

## 비용 요약

| 구성 | Pods | 월간 비용 | 설명 |
|------|------|-----------|------|
| **Active-Active** | 2 | **~$180** | 70/30 트래픽 분산 |
| DR Standby | 0 | ~$153 | 장애 시만 실행 |
| EC2 Node Group | N/A | ~$205 | Node 항상 running |

---

## Active-Active 선택 이유

### 1. 트래픽 분산
- On-prem 부하分散 (70%)
- EKS 부하 분산 (30%)
- HAProxy roundrobin으로 자동 분배

### 2. 고가용성
- 양쪽 모두 활성 → 단일 장애점 없음
- On-prem 실패 → EKS가 모든 트래픽 처리
- EKS 실패 → On-prem이 모든 트래픽 처리

### 3. 비용 효율
- Fargate pods만 실행 시 비용 발생
- Scale down → pods=0 → $153/month
- Scale up → pods=2 → $180/month

### 4. ECR 미러링 활용
- Harbor → ECR 자동 미러링
- EKS Fargate에서 ECR 직접 pull
- On-prem Harbor 장애 시 ECR fallback

---

## HAProxy Weight 설정

```yaml
# group_vars/aws_haproxy.yml
onprem_servers:
  - name: onprem-lb
    ip: 172.16.30.205
    port: 80
    weight: 70  # 70% traffic

eks_servers:
  - name: eks-active
    ip: k8s-kosa-xxx.elb.amazonaws.com
    port: 80
    weight: 30  # 30% traffic
```

### Weight 조절 예시

| 상황 | onprem weight | eks weight |
|------|---------------|------------|
| Normal | 70 | 30 |
| On-prem 부하 | 50 | 50 |
| EKS 테스트 | 30 | 70 |
| EKS만 사용 | 0 | 100 |
| On-prem만 사용 | 100 | 0 |

---

## Fargate Pod 비용 계산

```
Pod 비용 = (vCPU 비용 + Memory 비용) × 시간

vCPU: $0.04/vCPU-hour
Memory: $0.00353/GB-hour

1 pod (0.25 vCPU, 512Mi):
= ($0.04 × 0.25 + $0.00353 × 0.5) × 24 × 30
= ($0.01 + $0.00177) × 720
= $7.88/month

2 pods:
= $15.76/month
```

---

## Scripts

### Setup Active-Active
```bash
./04.k8s/scripts/eks/setup-active.sh
```

### Remove EKS (On-prem only)
```bash
./04.k8s/scripts/eks/remove-active.sh
```

### Scale Pods
```bash
# Scale up
kubectl -n kosa scale deployment web-app --replicas=4

# Scale down
kubectl -n kosa scale deployment web-app --replicas=0
```

---

## Recommendation

**Active-Active 구성으로 운영:**
- 70/30 트래픽 분산
- 월 ~$180 (Fargate 2 pods)
- 양쪽 장애 시 자동 failover
- ECR 미러링으로 이미지 가용성 보장